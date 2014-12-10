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

require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'
require 'chef/encrypted_attribute/assertions'
require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    class EncryptedMash
      # EncryptedMash Version2 format: using RSA with a shared secret and GCM.
      #
      # Uses public key cryptography (PKI) to encrypt a shared secret. Then this
      # shared secret is used to encrypt the data using [GCM]
      # (http://en.wikipedia.org/wiki/Galois/Counter_Mode).
      #
      # * This protocol version is based on the [Chef 12 Encrypted Data Bags
      #   Version 3 implementation](https://github.com/opscode/chef/pull/1591).
      # * To use it, the following **special requirements** must be met:
      #   Ruby `>= 2` and OpenSSL `>= 1.0.1`.
      # * This implementation can be improved, is not optimized either for
      #   performance or for space.
      # * Every time the `EncryptedAttribute` is updated, all the shared secrets
      #   are regenerated.
      #
      # # `EncryptedMash::Version2` Structure
      #
      # If you try to read this encrypted attribute structure, you can see a
      # `Mash` attribute with the following content:
      #
      # ```
      # EncryptedMash
      # ├── chef_type: "encrypted_attribute" (string).
      # ├── x_json_class: The used `EncryptedMash` version class name (string).
      # ├── encrypted_data
      # │   ├── cipher: The used PKI algorithm, "aes-256-gcm" (string).
      # │   ├── data: PKI encrypted data (base64).
      # │   ├── auth_tag: GCM authentication tag (base64).
      # │   └── iv: Initialization vector (in base64).
      # └── encrypted_secret
      #     ├── pub_key_hash1: The shared secret encrypted for the public key 1
      #     │     (base64).
      #     ├── pub_key_hash2: The shared secret encrypted for the public key 2
      #     │     (base64).
      #     └── ...
      # ```
      #
      # * `x_json_class` field is used, with the `x_` prefix, to be easily
      #   integrated with Chef in the future.
      #
      # ## `EncryptedMash[encrypted_data][data]`
      #
      # The data inside `encrypted_data` is symmetrically encrypted using the
      # secret shared key. The data is converted to *JSON* before the
      # encryption, then encrypted and finally encoded in *base64*. By default,
      # the `'aes-256-gcm'` algorithm is used for encryption.
      #
      # After decryption, the *JSON* has the following structure:
      #
      # ```
      # └── encrypted_data
      #     └── data (symmetrically encrypted JSON in base64)
      #         └── content: attribute content as a Mash.
      # ```
      #
      # * In the future, this structure may contain some metadata like default
      #   configuration values.
      #
      # ## `EncryptedMash[encrypted_secret][pub_key_hash1]`
      #
      # The `public_key_hash1` key value is the *SHA1* of the public key used
      # for encryption.
      #
      # Its content is the encrypted shared secret in *raw*. The encryption is
      # done using the *RSA* algorithm (PKI).
      #
      # After decryption, you find the shared secret in *raw* (in *Version1*
      # this is a *JSON* in *base64*).
      #
      # @see EncryptedMash
      class Version2 < Chef::EncryptedAttribute::EncryptedMash::Version1
        include Chef::EncryptedAttribute::Assertions

        # Symmetric [AEAD]
        # (http://en.wikipedia.org/wiki/AEAD_block_cipher_modes_of_operation)
        # algorithm to use by default.
        ALGORITHM = 'aes-256-gcm'

        # EncrytpedMash::Version2 constructor.
        #
        # Checks that GCM is correctly supported by Ruby and OpenSSL.
        #
        # @raise [RequirementsFailure] if the specified encrypted attribute
        #   version cannot be used.
        def initialize(enc_hs = nil)
          assert_aead_requirements_met!(ALGORITHM)
          super
        end

        # (see EncryptedMash::Version1#encrypt)
        def encrypt(value, public_keys)
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          # encrypt the data
          encrypted_data = symmetric_encrypt_value(value_json)
          # should no include the secret in clear
          secret = encrypted_data.delete('secret')
          self['encrypted_data'] = encrypted_data
          # encrypt the shared secret
          self['encrypted_secret'] = rsa_encrypt_multi_key(secret, public_keys)
          self
        end

        # (see EncryptedMash::Version1#decrypt)
        def decrypt(key)
          key = parse_decryption_key(key)
          enc_value = self['encrypted_data'].dup
          # decrypt the shared secret
          enc_value['secret'] =
            rsa_decrypt_multi_key(self['encrypted_secret'], key)
          # decrypt the data
          value_json = symmetric_decrypt_value(enc_value)
          json_decode(value_json)
        end

        protected

        # (see EncryptedMash::Version1#encrypted_data?)
        def encrypted_data?
          encrypted_data_contain_fields?(
            iv: String, auth_tag: String, data: String
          )
        end

        # (see EncryptedMash::Version1#encrypted?)
        def encrypted?
          Version0.instance_method(:encrypted?).bind(self).call &&
            encrypted_data? &&
            encrypted_secret?
        end

        # Encrypts a value using a symmetric [AEAD]
        # (http://en.wikipedia.org/wiki/AEAD_block_cipher_modes_of_operation)
        # cryptographic algorithm.
        #
        # Uses a randomly generated secret and IV.
        #
        # @param value [String] data to encrypt.
        # @param algo [String] symmetric algorithm to use.
        # @return [Mash] hash structure with symmetrically encrypted data:
        #   * `['cipher']`: algorithm used.
        #   * `['secret']`: random secret used for encryption in Base64.
        #   * `['iv']`: random initialization vector in Base64.
        #   * `['auth_tag']`: authentication tag in Base64.
        #   * `['data']`: data encrypted and in Base64.
        # @raise [EncryptionFailure] if encryption error.
        def symmetric_encrypt_value(value, algo = ALGORITHM)
          enc_value = Mash.new('cipher' => algo)
          begin
            cipher = OpenSSL::Cipher.new(algo)
            cipher.encrypt
            enc_value['secret'] = cipher.key = cipher.random_key
            enc_value['iv'] = Base64.encode64(cipher.iv = cipher.random_iv)
            enc_data = cipher.update(value) + cipher.final
            enc_value['auth_tag'] = Base64.encode64(cipher.auth_tag)
          rescue OpenSSL::Cipher::CipherError => e
            raise EncryptionFailure, "#{e.class.name}: #{e}"
          end
          enc_value['data'] = Base64.encode64(enc_data)
          enc_value
        end

        # Decrypts data using a symmetric [AEAD]
        # (http://en.wikipedia.org/wiki/AEAD_block_cipher_modes_of_operation)
        # cryptographic algorithm.
        #
        # @param enc_value [Mash] hash structure with encrypted data:
        #   * `['cipher']`: algorithm used.
        #   * `['secret']`: secret used for encryption in Base64.
        #   * `['iv']`: initialization vector in Base64.
        #   * `['auth_tag']`: authentication tag in Base64.
        #   * `['data']`: data encrypted in Base64.
        # @param algo [String] symmetric algorithm to use.
        # @raise [DecryptionFailure] if decryption error.
        # @see #symmetric_encrypt_value
        def symmetric_decrypt_value(enc_value, algo = ALGORITHM)
          # TODO: maybe it's better to ignore [cipher] ?
          cipher = OpenSSL::Cipher.new(enc_value['cipher'] || algo)
          cipher.decrypt
          # We must set key before iv: https://bugs.ruby-lang.org/issues/8221
          cipher.key = enc_value['secret']
          cipher.iv = Base64.decode64(enc_value['iv'])
          cipher.auth_tag = Base64.decode64(enc_value['auth_tag'])
          cipher.update(Base64.decode64(enc_value['data'])) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise DecryptionFailure, "#{e.class.name}: #{e}"
        end
      end
    end
  end
end
