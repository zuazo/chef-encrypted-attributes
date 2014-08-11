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

# Version1 format: using RSA with a shared secret and message authentication (HMAC)
class Chef
  class EncryptedAttribute
    class EncryptedMash
      class Version2 < Chef::EncryptedAttribute::EncryptedMash::Version1
        include Chef::EncryptedAttribute::Assertions

        ALGORITHM = 'aes-256-gcm'

        def initialize(enc_hs=nil)
          assert_aead_requirements_met!(ALGORITHM)
          super
        end

        def encrypt(value, public_keys)
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          # encrypt the data
          encrypted_data = symmetric_encrypt_value(value_json)
          secret = encrypted_data.delete('secret') # should no include the secret in clear
          self['encrypted_data'] = encrypted_data
          # encrypt the shared secret
          self['encrypted_secret'] = rsa_encrypt_multi_key(secret, public_keys)
          self
        end

        def decrypt(key)
          key = parse_decryption_key(key)
          enc_value = self['encrypted_data'].dup
          # decrypt the shared secret
          enc_value['secret'] = rsa_decrypt_multi_key(self['encrypted_secret'], key)
          # decrypt the data
          value_json = symmetric_decrypt_value(enc_value)
          json_decode(value_json)
        end

        protected

        def encrypted?
          Version0.instance_method(:encrypted?).bind(self).call and
          self['encrypted_data'].has_key?('iv') and
          self['encrypted_data']['iv'].kind_of?(String) and
          self['encrypted_data'].has_key?('auth_tag') and
          self['encrypted_data']['auth_tag'].kind_of?(String) and
          self['encrypted_data'].has_key?('data') and
          self['encrypted_data']['data'].kind_of?(String) and
          self['encrypted_secret'].kind_of?(Hash)
        end

        def symmetric_encrypt_value(value, algo=ALGORITHM)
          enc_value = Mash.new({ 'cipher' => algo })
          begin
            cipher = OpenSSL::Cipher.new(algo)
            cipher.encrypt
            enc_value['secret'] = cipher.key = cipher.random_key
            enc_value['iv'] = Base64.encode64(cipher.iv = cipher.random_iv)
            enc_data = cipher.update(value) + cipher.final
            enc_value['auth_tag'] = Base64.encode64(cipher.auth_tag)
          rescue OpenSSL::Cipher::CipherError => e
            raise EncryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
          enc_value['data'] = Base64.encode64(enc_data)
          enc_value
        end

        def symmetric_decrypt_value(enc_value, algo=ALGORITHM)
          cipher = OpenSSL::Cipher.new(enc_value['cipher'] || algo) # TODO maybe it's better to ignore [cipher] ?
          cipher.decrypt
          # We must set key before iv: https://bugs.ruby-lang.org/issues/8221
          cipher.key = enc_value['secret']
          cipher.iv = Base64.decode64(enc_value['iv'])
          cipher.auth_tag = Base64.decode64(enc_value['auth_tag'])
          cipher.update(Base64.decode64(enc_value['data'])) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
        end

      end
    end
  end
end
