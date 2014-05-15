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

# Version1 format: using RSA with a shared secret and message authentication (HMAC)
class Chef
  class EncryptedAttribute
    class EncryptedMash
      class Version1 < Chef::EncryptedAttribute::EncryptedMash::Version0
        SYMM_ALGORITHM = 'aes-256-cbc'
        HMAC_ALGORITHM = 'sha256'

        def encrypt(value, public_keys)
          secrets = {}
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          # encrypt the data
          encrypted_data = symmetric_encrypt_value(value_json)
          secrets['data'] = encrypted_data.delete('secret') # should no include the secret in clear
          self['encrypted_data'] = encrypted_data
          # generate hmac (encrypt-then-mac), excluding the secret
          hmac = generate_hmac(json_encode(self['encrypted_data'].sort))
          secrets['hmac'] = hmac['secret']
          self['hmac'] = hmac['data']
          # encrypt the shared secrets
          self['encrypted_secret'] = rsa_encrypt_multi_key(json_encode(secrets), public_keys)
          self
        end

        def decrypt(key)
          key = parse_decryption_key(key)
          enc_value = self['encrypted_data'].dup
          # decrypt the shared secrets
          secrets = json_decode(rsa_decrypt_multi_key(self['encrypted_secret'], key))
          enc_value['secret'] = secrets['data']
          # check hmac (encrypt-then-mac -> mac-then-decrypt)
          unless hmac_matches?(self['hmac'], json_encode(self['encrypted_data'].sort), secrets['hmac'])
            raise DecryptionFailure, 'Error decrypting encrypted attribute: invalid hmac. Most likely the data is corrupted.'
          end
          # decrypt the data
          value_json = symmetric_decrypt_value(enc_value)
          json_decode(value_json)
        end

        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          parse_public_keys(keys).reduce(true) do |r, k|
            r and data_can_be_decrypted_by_key?(self['encrypted_secret'], k)
          end
        end

        def needs_update?(keys)
          keys = parse_public_keys(keys)
          not can_be_decrypted_by?(keys) && self['encrypted_secret'].keys.count == keys.count
        end

        protected

        def encrypted?
          super and
          self['encrypted_data'].has_key?('iv') and
          self['encrypted_data']['iv'].kind_of?(String) and
          self['encrypted_data'].has_key?('data') and
          self['encrypted_data']['data'].kind_of?(String) and
          self['encrypted_secret'].kind_of?(Hash) and
          self['hmac'].kind_of?(String)
        end

        def symmetric_encrypt_value(value, algo=SYMM_ALGORITHM)
          enc_value = Mash.new({ 'cipher' => algo })
          begin
            cipher = OpenSSL::Cipher.new(algo)
            cipher.encrypt
            enc_value['iv'] = Base64.encode64(cipher.iv = cipher.random_iv)
            enc_value['secret'] = Base64.encode64(cipher.key = cipher.random_key)
            enc_data = cipher.update(value) + cipher.final
          rescue OpenSSL::Cipher::CipherError => e
            raise EncryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
          enc_value['data'] = Base64.encode64(enc_data)
          enc_value
        end

        def symmetric_decrypt_value(enc_value, algo=SYMM_ALGORITHM)
          begin
            cipher = OpenSSL::Cipher.new(enc_value['cipher'] || algo) # TODO maybe it's better to ignore [cipher] ?
            cipher.decrypt
            cipher.iv = Base64.decode64(enc_value['iv'])
            cipher.key = Base64.decode64(enc_value['secret'])
            dec_data = cipher.update(Base64.decode64(enc_value['data'])) + cipher.final
          rescue OpenSSL::Cipher::CipherError => e
            raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
          dec_data
        end

        def generate_hmac(data, algo=HMAC_ALGORITHM)
          hmac = Mash.new
          begin
            digest = OpenSSL::Digest.new(algo)
            secret = OpenSSL::Random.random_bytes(digest.block_length)
            hmac['secret'] = Base64.encode64(secret)
            hmac['data'] = Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          rescue OpenSSL::Digest::DigestError, OpenSSL::HMACError, RuntimeError => e
            # RuntimeError is raised for unsupported algorithms
            raise MessageAuthenticationFailure, "#{e.class.name}: #{e.to_s}"
          end
          hmac
        end

        def hmac_matches?(orig_hmac, data, secret, algo=HMAC_ALGORITHM)
          begin
            digest = OpenSSL::Digest.new(algo)
            secret = Base64.decode64(secret)
            new_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, secret, data))
          rescue OpenSSL::Digest::DigestError, OpenSSL::HMACError, RuntimeError => e
            # RuntimeError is raised for unsupported algorithms
            raise MessageAuthenticationFailure, "#{e.class.name}: #{e.to_s}"
          end
          orig_hmac == new_hmac
        end

      end
    end
  end
end
