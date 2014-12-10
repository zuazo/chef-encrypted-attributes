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
require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    class EncryptedMash
      # EncryptedMash Version1 format: using RSA with a shared secret and
      # message authentication (HMAC).
      #
      # This is the {EncryptedMash} version used by default. Uses public key
      # cryptography (PKI) to encrypt a shared secret. Then this shared secret
      # is used to encrypt the data.
      #
      # * This implementation can be improved, is not optimized either for
      #   performance or for space.
      # * Every time the `EncryptedAttribute` is updated, all the shared secrets
      #   are regenerated.
      #
      # # `EncryptedMash::Version1` Structure
      #
      # If you try to read this encrypted attribute structure, you can see a
      # `Mash` attribute with the following content:
      #
      # ```
      # EncryptedMash
      # ├── chef_type: "encrypted_attribute" (string).
      # ├── x_json_class: The used `EncryptedMash` version class name (string).
      # ├── encrypted_data
      # │   ├── cipher: The used PKI algorithm, "aes-256-cbc" (string).
      # │   ├── data: PKI encrypted data (base64).
      # │   └── iv: Initialization vector (in base64).
      # ├── encrypted_secret
      # │   ├── pub_key_hash1: The shared secrets encrypted for the public key 1
      # │   │     (base64).
      # │   ├── pub_key_hash2: The shared secrets encrypted for the public key 2
      # │   │     (base64).
      # │   └── ...
      # └── hmac
      #     ├── cipher: The used HMAC algorithm, currently ignored and always
      #     │     "sha256" (string).
      #     └── data: Hash-based message authentication code value (base64).
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
      # the `'aes-256-cbc'` algorithm is used for encryption.
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
      # Its content is the encrypted shared secrets in *base64*. The encryption
      # is done using the *RSA* algorithm (PKI).
      #
      # After decryption, you find the following structure in *JSON*:
      #
      # ```
      # └── encrypted_secret
      #     └── pub_key_hash1 (PKI encrypted JSON in base64)
      #         ├── data: The shared secret used to encrypt the data (base64).
      #         └── hmac: The shared secret used for the HMAC calculation
      #               (base64).
      # ```
      #
      # ## `EncryptedMash[hmac][data]`
      #
      # The HMAC data is in *base64*. The hashing algorithm used is `'sha256'`.
      #
      # The following data is used in a alphabetically sorted *JSON* to
      # calculate the HMAC:
      #
      # ```
      # Data to calculate the HMAC from
      # ├── cipher: The algorithm used for `encrypted_data` encryption
      # │     ("aes-256-cbc").
      # ├── data: The `encrypted_data` data content after the encryption
      # │     (encrypt-then-mac).
      # └── iv: The initialization vector used to encrypt the encrypted_data.
      # ```
      #
      # * All the data required for decryption is included in the HMAC (except
      #   the secret key, of course): `cipher`, `data` and `iv`.
      # * The data used to calculate the HMAC is the encrypted data, not the
      #   clear text data (**Encrypt-then-MAC**).
      # * The secret used to calculate the HMAC is not the same as the secret
      #   used to encrypt the data.
      # * The secret used to calculate the HMAC is shared inside
      #   `encrypted_secret` field with the data secret.
      #
      # @see EncryptedMash
      class Version1 < Chef::EncryptedAttribute::EncryptedMash::Version0
        # Symmetric algorithm to use by default.
        SYMM_ALGORITHM = 'aes-256-cbc'
        # Algorithm used for HMAC calculation.
        HMAC_ALGORITHM = 'sha256'

        # (see EncryptedMash::Version0#encrypt)
        def encrypt(value, public_keys)
          secrets = {}
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          # encrypt the data
          encrypted_data = symmetric_encrypt_value(value_json)
          # should no include the secret in clear
          secrets['data'] = encrypted_data.delete('secret')
          self['encrypted_data'] = encrypted_data
          # generate hmac (encrypt-then-mac), excluding the secret
          hmac = generate_hmac(json_encode(self['encrypted_data'].sort))
          secrets['hmac'] = hmac.delete('secret')
          self['hmac'] = hmac
          # encrypt the shared secrets
          self['encrypted_secret'] =
            rsa_encrypt_multi_key(json_encode(secrets), public_keys)
          self
        end

        # (see EncryptedMash::Version0#decrypt)
        def decrypt(key)
          key = parse_decryption_key(key)
          enc_value = self['encrypted_data'].dup
          hmac = self['hmac'].dup
          # decrypt the shared secrets
          secrets =
            json_decode(rsa_decrypt_multi_key(self['encrypted_secret'], key))
          enc_value['secret'] = secrets['data']
          hmac['secret'] = secrets['hmac']
          # check hmac (encrypt-then-mac -> mac-then-decrypt)
          unless hmac_matches?(hmac, json_encode(self['encrypted_data'].sort))
            fail DecryptionFailure,
                 'Error decrypting encrypted attribute: invalid hmac. Most '\
                 'likely the data is corrupted.'
          end
          # decrypt the data
          value_json = symmetric_decrypt_value(enc_value)
          json_decode(value_json)
        end

        # (see EncryptedMash::Version0#can_be_decrypted_by?)
        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          data_can_be_decrypted_by_keys?(self['encrypted_secret'], keys)
        end

        # (see EncryptedMash::Version0#needs_update?)
        def needs_update?(keys)
          keys = parse_public_keys(keys)
          !can_be_decrypted_by?(keys) ||
            self['encrypted_secret'].keys.count != keys.count
        end

        protected

        # Checks if the encrypted data Mash contains all the fields an has the
        # correct type.
        #
        # Checks the `self['encrypted_data']` structure.
        #
        # @param [Hash<Symbol, Class>] fields to check. For example:
        #   `{ iv: String, data: String }`.
        # @return [Boolean] `true` if all the fields are exists.
        def encrypted_data_contain_fields?(fields)
          data = self['encrypted_data']
          fields.reduce(true) do |r, (field, kind_of)|
            r && data.key?(field) && data[field].is_a?(kind_of)
          end
        end

        # Checks if the encrypted data structure is correct.
        #
        # Checks the `self['encrypted_data']` structure.
        #
        # @return [Boolean] `true` if it is correct.
        def encrypted_data?
          encrypted_data_contain_fields?(iv: String, data: String)
        end

        # Checks if the encrypted secrets structure is correct.
        #
        # Checks the `self['encrypted_secret']` structure.
        #
        # @return [Boolean] `true` if it is correct.
        def encrypted_secret?
          self['encrypted_secret'].is_a?(Hash)
        end

        # Checks if the HMAC structure is correct.
        #
        # Checks the `self['hmac']` structure.
        #
        # @return [Boolean] `true` if it is correct.
        def encrypted_hmac?
          self['hmac'].is_a?(Hash) &&
            self['hmac'].key?('data') &&
            self['hmac']['data'].is_a?(String)
        end

        # (see EncryptedMash::Version0#encrypted?)
        def encrypted?
          super &&
            encrypted_data? &&
            encrypted_secret? &&
            encrypted_hmac?
        end

        # Encrypts a value using a symmetric cryptographic algorithm.
        #
        # Uses a randomly generated secret and IV.
        #
        # @param value [String] data to encrypt.
        # @param algo [String] symmetric algorithm to use.
        # @return [Mash] hash structure with symmetrically encrypted data:
        #   * `['cipher']`: algorithm used.
        #   * `['secret']`: random secret used for encryption in Base64.
        #   * `['iv']`: random initialization vector in Base64.
        #   * `['data']`: data encrypted and in Base64.
        # @raise [EncryptionFailure] if encryption error.
        def symmetric_encrypt_value(value, algo = SYMM_ALGORITHM)
          enc_value = Mash.new('cipher' => algo)
          begin
            cipher = OpenSSL::Cipher.new(algo)
            cipher.encrypt
            enc_value['secret'] =
              Base64.encode64(cipher.key = cipher.random_key)
            enc_value['iv'] = Base64.encode64(cipher.iv = cipher.random_iv)
            enc_data = cipher.update(value) + cipher.final
          rescue OpenSSL::Cipher::CipherError => e
            raise EncryptionFailure, "#{e.class.name}: #{e}"
          end
          enc_value['data'] = Base64.encode64(enc_data)
          enc_value
        end

        # Decrypts data using a symmetric cryptographic algorithm.
        #
        # @param enc_value [Mash] hash structure with encrypted data:
        #   * `['cipher']`: algorithm used.
        #   * `['secret']`: secret used for encryption in Base64.
        #   * `['iv']`: initialization vector in Base64.
        #   * `['data']`: data encrypted in Base64.
        # @param algo [String] symmetric algorithm to use.
        # @raise [DecryptionFailure] if decryption error.
        # @see #symmetric_encrypt_value
        def symmetric_decrypt_value(enc_value, algo = SYMM_ALGORITHM)
          # TODO: maybe it's better to ignore [cipher] ?
          cipher = OpenSSL::Cipher.new(enc_value['cipher'] || algo)
          cipher.decrypt
          # We must set key before iv: https://bugs.ruby-lang.org/issues/8221
          cipher.key = Base64.decode64(enc_value['secret'])
          cipher.iv = Base64.decode64(enc_value['iv'])
          cipher.update(Base64.decode64(enc_value['data'])) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise DecryptionFailure, "#{e.class.name}: #{e}"
        end

        # Exception list raised by the HMAC calculation process.
        #
        # `RuntimeError` is raised for unsupported algorithms.
        #
        # @api private
        HMAC_EXCEPTIONS =
          [OpenSSL::Digest::DigestError, OpenSSL::HMACError, RuntimeError]

        # Calculates [HMAC]
        # (http://en.wikipedia.org/wiki/Hash-based_message_authentication_code)
        # value for data.
        #
        # Uses a randomly generated secret for the HMAC calculation.
        #
        # @param data [String] data to calculate HMAC for.
        # @param algo [String] HMAC algorithm to use.
        # @return [Mash] hash structure with HMAC data:
        #   * `['cipher']`: algorithm used.
        #   * `['secret']` random secret used for HMAC calculation in Base64.
        #   * `['data']` HMAC value in Base64.
        # @raise [MessageAuthenticationFailure] if HMAC calculation error.
        def generate_hmac(data, algo = HMAC_ALGORITHM)
          # [cipher] is ignored, only as info
          hmac = Mash.new('cipher' => algo)
          digest = OpenSSL::Digest.new(algo)
          secret = OpenSSL::Random.random_bytes(digest.block_length)
          hmac['secret'] = Base64.encode64(secret)
          hmac['data'] =
            Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          hmac
        rescue *HMAC_EXCEPTIONS => e
          raise MessageAuthenticationFailure, "#{e.class}: #{e}"
        end

        # Checks if the [HMAC]
        # (http://en.wikipedia.org/wiki/Hash-based_message_authentication_code)
        # matches
        #
        # Uses a randomly generated secret for the HMAC calculation.
        #
        # @param orig_hmac [Mash] hash structure with HMAC data:
        #   * `['cipher']`: algorithm used (this is ignored).
        #   * `['secret']` secret used for HMAC calculation in Base64.
        #   * `['data']` HMAC value in Base64.
        # @param data [String] data to calculate HMAC for.
        # @param algo [String] HMAC algorithm to use.
        # @return [Boolean] `true` if HMAC value matches.
        # @raise [MessageAuthenticationFailure] if HMAC calculation error.
        # @see #generate_hmac
        def hmac_matches?(orig_hmac, data, algo = HMAC_ALGORITHM)
          digest = OpenSSL::Digest.new(algo)
          secret = Base64.decode64(orig_hmac['secret'])
          new_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          orig_hmac['data'] == new_hmac
        rescue *HMAC_EXCEPTIONS => e
          raise MessageAuthenticationFailure, "#{e.class}: #{e}"
        end
      end
    end
  end
end
