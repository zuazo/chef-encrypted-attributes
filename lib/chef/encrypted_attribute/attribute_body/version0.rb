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

require 'chef/encrypted_attribute/attribute_body/version'
require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    class AttributeBody
      class Version0 < Chef::EncryptedAttribute::AttributeBody::Version

        def encrypt(value, public_keys)
          value_json = json_encode(value)
          public_keys = public_keys_uniq(public_keys)
          self['encrypted_rsa_data'] = Mash.new(Hash[
            public_keys.map do |public_key|
              [
                node_key(public_key),
                encrypt_value(public_key, value_json),
              ]
            end
          ])
          self
        end

        def decrypt(key)
          key = pem_to_key(key)
          unless key.public? and key.private?
            raise InvalidPrivateKey, 'The provided key for decryption is invalid, a valid public and private key is required.'
          end
          unless can_be_decrypted_by?(key) # TODO optimize, node key digest is calculated multiple times
            raise DecryptionFailure, 'Attribute data cannot be decrypted by the provided key.'
          end

          enc_value = self['encrypted_rsa_data'][node_key(key.public_key)]
          value_json = decrypt_value(key, enc_value)
          json_decode(value_json)
          # we avoid saving the decrypted value, only return it
        end

        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          public_keys_uniq(keys).reduce(true) do |r, k|
            r and self['encrypted_rsa_data'].has_key?(node_key(k.public_key))
          end
        end

        def needs_update?(keys)
          keys = public_keys_uniq(keys)
          not can_be_decrypted_by?(keys) && self['encrypted_rsa_data'].keys.count == keys.count
        end

        protected

        def encrypted?
          has_key?('encrypted_rsa_data') and self['encrypted_rsa_data'].kind_of?(Hash)
        end

        def pem_to_key(k)
          begin
            k.kind_of?(OpenSSL::PKey::RSA) ? k : OpenSSL::PKey::RSA.new(k)
          rescue OpenSSL::PKey::RSAError, TypeError => e
            raise InvalidPrivateKey, "The provided key is invalid: #{k.inspect}"
          end
        end

        def public_keys_uniq(keys)
          keys = [ keys ].flatten
          keys.map do |k|
            k = pem_to_key(k)
            unless k.public?
              raise InvalidPublicKey, 'Some provided public keys are invalid.'
            end
            k
          end.uniq { |k| k.public_key.to_s.chomp }
        end

        def json_encode(o)
          # Array to avoid using quirks mode, create standard JSON
          [ o ].to_json
        end

        def json_decode(o)
          begin
            JSON.parse(o.to_s)[0]
          rescue JSON::ParserError => e
            raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

        def node_key(public_key)
          Digest::SHA1.hexdigest(public_key.to_der)
        end

        def encrypt_value(public_key, value)
          begin
            Base64.encode64(public_key.public_encrypt(value))
          rescue OpenSSL::PKey::RSAError => e
            raise EncryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

        def decrypt_value(key, value)
          begin
            key.private_decrypt(Base64.decode64(value.to_s))
          rescue OpenSSL::PKey::RSAError => e
            raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

      end
    end
  end
end
