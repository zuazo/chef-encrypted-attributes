# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL. (www.onddo.com)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/version'
require 'chef/encrypted_attribute/encrypted_mash'
require 'chef/encrypted_attribute/exceptions'

# Use the YAJL library that Chef provides.  Determine which to use based on
# Chef version.
major, minor = Chef::VERSION.split('.').take(2).map(&:to_i)
if ([major, minor] <=> [11, 12]) == 1 # If [major, minor] > [11, 12]
  require 'ffi_yajl'
  YAJL_NAMESPACE = FFI_Yajl
else
  require 'yajl'
  YAJL_NAMESPACE = Yajl
end

class Chef
  class EncryptedAttribute
    class EncryptedMash
      # EncryptedMash Version0 format: using RSA without shared secret.
      #
      # This is the first version, considered old. Uses public key cryptography
      # (PKI) to encrypt the data. There is no shared secret or HMAC for data
      # integrity checking.
      #
      # # `EncryptedMash::Version0` Structure
      #
      # If you try to read this encrypted attribute structure, you can see a
      # `Chef::Mash` attribute with the following content:
      #
      # ```
      # EncryptedMash
      # └── encrypted_data
      #     ├── pub_key_hash1: The data encrypted using PKI for the public key 1
      #     │     (base64)
      #     ├── pub_key_hash2: The data encrypted using PKI for the public key 2
      #     │     (base64)
      #     └── ...
      # ```
      #
      # The `public_key_hash1` key value is the *SHA1* of the public key used
      # for encryption.
      #
      # Its content is the data encoded in *JSON*, then encrypted with the
      # public key, and finally encoded in *base64*. The encryption is done
      # using the *RSA* algorithm (PKI).
      #
      # @see EncryptedMash
      class Version0 < Chef::EncryptedAttribute::EncryptedMash
        # Encrypts data inside the current {EncryptedMash} object.
        #
        # @param value [Mixed] value to encrypt, will be converted to JSON.
        # @param public_keys [Array<String, OpenSSL::PKey::RSA>] publics keys
        #   that will be able to decrypt the {EncryptedMash}.
        # @return [EncryptedMash] the value encrypted.
        # @raise [EncryptionFailure] if there are encryption errors.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def encrypt(value, public_keys)
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          self['encrypted_data'] =
            rsa_encrypt_multi_key(value_json, public_keys)
          self
        end

        # Decrypts the current {EncryptedMash} object.
        #
        # @param key [String, OpenSSL::PKey::RSA] RSA private key used to
        #   decrypt.
        # @return [Mixed] the value decrypted.
        # @raise [DecryptionFailure] if the data cannot be decrypted by the
        #   provided key.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def decrypt(key)
          key = parse_decryption_key(key)
          value_json = rsa_decrypt_multi_key(self['encrypted_data'], key)
          json_decode(value_json)
          # we avoid saving the decrypted value, only return it
        end

        # Checks if the current {EncryptedMash} can be decrypted by all of the
        # provided keys.
        #
        # @param keys [Array<OpenSSL::PKey::RSA>] list of public keys.
        # @return [Boolean] `true` if all keys can decrypt the data.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          data_can_be_decrypted_by_keys?(self['encrypted_data'], keys)
        end

        # Checks if the current {EncryptedMash} needs to be re-encrypted.
        #
        # This usually happends when new keys are provided or some keys are
        # removed from the previous encryption process.
        #
        # In other words, this method checks all key can decrypt the data and
        # only those keys.
        #
        # @param keys [Array<String, OpenSSL::PKey::RSA>] list of RSA public
        #   keys.
        # @return [Boolean] `true` if all keys can decrypt the data and only
        #   those keys can decrypt the data.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def needs_update?(keys)
          keys = parse_public_keys(keys)
          !can_be_decrypted_by?(keys) ||
            self['encrypted_data'].keys.count != keys.count
        end

        protected

        # Checks if encrypted data exists in the current Mash.
        #
        # @return [Boolean] `true` if there is encrypted data.
        def encrypted?
          key?('encrypted_data') && self['encrypted_data'].is_a?(Hash)
        end

        # Converts the RSA key to an `OpenSSL::PKey::RSA` object.
        #
        # @param k [String, OpenSSL::PKey::RSA] RSA key to convert.
        # @return [OpenSSL::PKey::RSA] RSA key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def pem_to_key(k)
          k.is_a?(OpenSSL::PKey::RSA) ? k : OpenSSL::PKey::RSA.new(k)
        rescue OpenSSL::PKey::RSAError, TypeError
          raise InvalidKey, "The provided key is invalid: #{k.inspect}"
        end

        # Parses a RSA public key used for encryption.
        #
        # @param key [String, OpenSSL::PKey::RSA] RSA key to parse.
        # @return [OpenSSL::PKey::RSA] RSA public key.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def parse_public_key(key)
          key = pem_to_key(key)
          unless key.public?
            fail InvalidPublicKey, 'Invalid public key provided.'
          end
          key
        end

        # Parses a RSA key used for decryption. Must contain both the public
        # and the private key. It also checks that the current {EncryptedMash}
        # object can be decrypted by the provided key.
        #
        # @param key [String, OpenSSL::PKey::RSA] RSA key to parse.
        # @return [OpenSSL::PKey::RSA] RSA key.
        # @raise [DecryptionFailure] if the data cannot be decrypted by the
        #   provided key.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def parse_decryption_key(key)
          key = pem_to_key(key)
          unless key.public? && key.private?
            fail InvalidKey,
                 'The provided key for decryption is invalid, a valid public '\
                 'and private key is required.'
          end
          # TODO: optimize, node key digest is calculated multiple times
          unless can_be_decrypted_by?(key)
            fail DecryptionFailure,
                 'Attribute data cannot be decrypted by the provided key.'
          end
          key
        end

        # Parses a list of RSA public keys, used for encryption.
        #
        # @param keys [Array<String, OpenSSL::PKey::RSA>] list of keys.
        # @return [Array<OpenSSL::PKey::RSA>] list of keys parsed.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def parse_public_keys(keys)
          keys = [keys].flatten
          keys_parsed = keys.map { |k| parse_public_key(k) }
          keys_parsed.uniq { |k| k.public_key.to_s.chomp }
        end

        # Converts an object to its JSON representation.
        #
        # @param o [Mixed] object to convert.
        # @return [String] JSON object as string.
        def json_encode(o)
          # TODO: This does not check if the object is correct, should be an
          # Array or a Hash
          YAJL_NAMESPACE::Encoder.encode(o)
        end

        # Decodes a JSON string.
        #
        # @param o [String] JSON string to decode.
        # @return [Mixed] Ruby representation of the JSON string.
        # @raise [DecryptionFailure] if JSON string format is wrong.
        def json_decode(o)
          YAJL_NAMESPACE::Parser.parse(o.to_s)
        rescue YAJL_NAMESPACE::ParseError => e
          raise DecryptionFailure, "#{e.class.name}: #{e}"
        end

        # Encodes Ruby `< 1.9.3` RSA key using X.509 format.
        #
        # In Ruby `< 1.9.3` RSA keys are in [PKCS#1]
        # (http://en.wikipedia.org/wiki/PKCS_1) format.
        #
        # In Ruby `>= 1.9.3` RSA keys are in [X.509]
        # (http://en.wikipedia.org/wiki/X.509) format (private keys in [PKCS#8]
        # (http://en.wikipedia.org/wiki/PKCS_8)).
        #
        # @param rsa [OpenSSL::PKey::RSA] RSA key.
        # @return [OpenSSL::ASN1::Sequence] RSA key in X.509 format.
        # @note Heavily based on @sl4m code:
        #   https://gist.github.com/sl4m/1470360
        def rsa_ensure_x509_ruby192(rsa)
          modulus = rsa.n
          exponent = rsa.e

          asn1 = OpenSSL::ASN1
          oid = asn1::ObjectId.new('rsaEncryption')
          alg_id = asn1::Sequence.new([oid, asn1::Null.new(nil)])
          ary = [asn1::Integer.new(modulus), asn1::Integer.new(exponent)]
          pub_key = asn1::Sequence.new(ary)
          enc_pk = asn1::BitString.new(pub_key.to_der)
          asn1::Sequence.new([alg_id, enc_pk])
        end

        # Returns any RSA key in X.509 format.
        #
        # Fixes RSA key format in Ruby `< 1.9.3`.
        #
        # @param rsa [OpenSSL::PKey::RSA] RSA key.
        # @return [OpenSSL::ASN1::Sequence] RSA key in X.509 format.
        # @see #rsa_ensure_x509_ruby192
        def rsa_ensure_x509(rsa)
          RUBY_VERSION < '1.9.3' ? rsa_ensure_x509_ruby192(rsa) : rsa
        end

        # Gets the hash key to use for saving the encrypted data for a node.
        #
        # It uses a SHA1 hexadecimal digest of the public key as key.
        #
        # @param public_key [OpenSSL::PKey::RSA] RSA public key.
        # @return [String] hash key for the public key.
        def node_key(public_key)
          Digest::SHA1.hexdigest(rsa_ensure_x509(public_key).to_der)
        end

        # Encrypts a value using a RSA public key.
        #
        # @param value [String] data to encrypt.
        # @param public_key [OpenSSL::PKey::RSA] public key used for encryption.
        # @return [String] data encrypted in its Base64 representation.
        # @raise [EncryptionFailure] if there are encryption errors.
        def rsa_encrypt_value(value, public_key)
          Base64.encode64(public_key.public_encrypt(value))
        rescue OpenSSL::PKey::RSAError => e
          raise EncryptionFailure, "#{e.class.name}: #{e}"
        end

        # Decrypts a value using a RSA private key.
        #
        # @param value [String] encrypted data to decrypt in its Base64
        #   representation.
        # @param key [OpenSSL::PKey::RSA] private key used for decryption.
        # @return [String] value decrypted.
        # @raise [DecryptionFailure] if there are decryption errors.
        def rsa_decrypt_value(value, key)
          key.private_decrypt(Base64.decode64(value.to_s))
        rescue OpenSSL::PKey::RSAError => e
          raise DecryptionFailure, "#{e.class.name}: #{e}"
        end

        # Returns data encrypted for multiple keys using RSA.
        #
        # Returns a `Mash` with the following structure:
        # * Hash keys: hexadecimal SHA1 of the public key.
        # * Hash values: RSA encrypted data and then converted to Base64.
        #
        # @param value [String] data to encrypt.
        # @param public_keys [Array<OpenSSL::PKey::RSA>] public keys list.
        # @return [Mash] data encrypted.
        # @raise [EncryptionFailure] if there are encryption errors.
        # @see #node_key
        # @see #rsa_encrypt_value
        def rsa_encrypt_multi_key(value, public_keys)
          Mash.new(Hash[
            public_keys.map do |public_key|
              [node_key(public_key), rsa_encrypt_value(value, public_key)]
            end
         ])
        end

        # Decrypts RSA value from a data structure encrypted for multiple keys.
        #
        # @param enc_value [Mash] encrypted data structure.
        # @param key [OpenSSL::PKey::RSA] RSA key to use (public and private key
        #   is required).
        # @return [String] data decrypted.
        # @see #rsa_decrypt_value
        def rsa_decrypt_multi_key(enc_value, key)
          enc_value = enc_value[node_key(key.public_key)]
          rsa_decrypt_value(enc_value, key)
        end

        # Checks if data can be decrypted by the provided key. Where data is
        # encrypted for multiple keys.
        #
        # This method is not immune to any kind of data corruption. Only checks
        # that the data seems to be decipherable by the key. No MAC checking.
        #
        # @param enc_value [Mash] encrypted data structure.
        # @param key [OpenSSL::PKey::RSA] RSA key.
        # @return [Boolean] `true` if the data can be decrypted.
        # @see #rsa_encrypt_multi_key
        def data_can_be_decrypted_by_key?(enc_value, key)
          enc_value.key?(node_key(key.public_key))
        end

        # Checks if the data can be decrypted by all of the provided keys.
        #
        # @param data [Mash] encrypted data to check. This usually refers to
        #   `self['encrypted_data']`.
        # @param keys [Array<OpenSSL::PKey::RSA>] list of public keys.
        # @return [Boolean] `true` if all keys can decrypt the data.
        # @raise [InvalidPublicKey] if it is not a valid RSA public key.
        # @raise [InvalidKey] if the RSA key format is wrong.
        def data_can_be_decrypted_by_keys?(data, keys)
          parse_public_keys(keys).reduce(true) do |r, k|
            r && data_can_be_decrypted_by_key?(data, k)
          end
        end
      end
    end
  end
end
