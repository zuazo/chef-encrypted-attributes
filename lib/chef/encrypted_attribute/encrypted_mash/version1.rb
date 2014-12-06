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
      # message authentication (HMAC)
      class Version1 < Chef::EncryptedAttribute::EncryptedMash::Version0
        SYMM_ALGORITHM = 'aes-256-cbc'
        HMAC_ALGORITHM = 'sha256'

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

        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          parse_public_keys(keys).reduce(true) do |r, k|
            r && data_can_be_decrypted_by_key?(self['encrypted_secret'], k)
          end
        end

        def needs_update?(keys)
          keys = parse_public_keys(keys)
          !can_be_decrypted_by?(keys) ||
            self['encrypted_secret'].keys.count != keys.count
        end

        protected

        def encrypted_data?
          self['encrypted_data'].key?('iv') &&
            self['encrypted_data']['iv'].is_a?(String) &&
            self['encrypted_data'].key?('data') &&
            self['encrypted_data']['data'].is_a?(String)
        end

        def encrypted_secret?
          self['encrypted_secret'].is_a?(Hash)
        end

        def encrypted_hmat?
          self['hmac'].is_a?(Hash) &&
            self['hmac'].key?('data') &&
            self['hmac']['data'].is_a?(String)
        end

        def encrypted?
          super &&
            encrypted_data? &&
            encrypted_secret? &&
            encrypted_hmat?
        end

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

        def generate_hmac(data, algo = HMAC_ALGORITHM)
          # [cipher] is ignored, only as info
          hmac = Mash.new('cipher' => algo)
          digest = OpenSSL::Digest.new(algo)
          secret = OpenSSL::Random.random_bytes(digest.block_length)
          hmac['secret'] = Base64.encode64(secret)
          hmac['data'] =
            Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          hmac
        rescue OpenSSL::Digest::DigestError, OpenSSL::HMACError,
               RuntimeError => e
          # RuntimeError is raised for unsupported algorithms
          raise MessageAuthenticationFailure, "#{e.class.name}: #{e}"
        end

        def hmac_matches?(orig_hmac, data, algo = HMAC_ALGORITHM)
          digest = OpenSSL::Digest.new(algo)
          secret = Base64.decode64(orig_hmac['secret'])
          new_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          orig_hmac['data'] == new_hmac
        rescue OpenSSL::Digest::DigestError, OpenSSL::HMACError,
               RuntimeError => e
          # RuntimeError is raised for unsupported algorithms
          raise MessageAuthenticationFailure, "#{e.class.name}: #{e}"
        end
      end
    end
  end
end
