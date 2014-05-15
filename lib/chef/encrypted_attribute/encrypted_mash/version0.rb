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

require 'chef/encrypted_attribute/encrypted_mash'
require 'chef/encrypted_attribute/exceptions'
require 'yajl'

# Version0 format: using RSA without shared secret
class Chef
  class EncryptedAttribute
    class EncryptedMash
      class Version0 < Chef::EncryptedAttribute::EncryptedMash

        def encrypt(value, public_keys)
          value_json = json_encode(value)
          public_keys = parse_public_keys(public_keys)
          self['encrypted_data'] = rsa_encrypt_multi_key(value_json, public_keys)
          self
        end

        def decrypt(key)
          key = parse_decryption_key(key)
          value_json = rsa_decrypt_multi_key(self['encrypted_data'], key)
          json_decode(value_json)
          # we avoid saving the decrypted value, only return it
        end

        def can_be_decrypted_by?(keys)
          return false unless encrypted?
          parse_public_keys(keys).reduce(true) do |r, k|
            r and data_can_be_decrypted_by_key?(self['encrypted_data'], k)
          end
        end

        def needs_update?(keys)
          keys = parse_public_keys(keys)
          not can_be_decrypted_by?(keys) && self['encrypted_data'].keys.count == keys.count
        end

        protected

        def encrypted?
          has_key?('encrypted_data') and self['encrypted_data'].kind_of?(Hash)
        end

        def pem_to_key(k)
          begin
            k.kind_of?(OpenSSL::PKey::RSA) ? k : OpenSSL::PKey::RSA.new(k)
          rescue OpenSSL::PKey::RSAError, TypeError => e
            raise InvalidPrivateKey, "The provided key is invalid: #{k.inspect}"
          end
        end

        def parse_public_key(key)
          key = pem_to_key(key)
          unless key.public?
            raise InvalidPublicKey, 'Invalid public key provided.'
          end
          key
        end

        def parse_decryption_key(key)
          key = pem_to_key(key)
          unless key.public? and key.private?
            raise InvalidPrivateKey, 'The provided key for decryption is invalid, a valid public and private key is required.'
          end
          unless can_be_decrypted_by?(key) # TODO optimize, node key digest is calculated multiple times
            raise DecryptionFailure, 'Attribute data cannot be decrypted by the provided key.'
          end
          key
        end

        def parse_public_keys(keys)
          keys = [ keys ].flatten
          keys.map do |k|
            parse_public_key(k)
          end.uniq { |k| k.public_key.to_s.chomp }
        end

        def json_encode(o)
          # TODO This does not check if the object is correct, should be an Array or a Hash
          Yajl::Encoder.encode(o)
        end

        def json_decode(o)
          begin
            Yajl::Parser.parse(o.to_s)
          rescue Yajl::ParseError => e
            raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

        def node_key(public_key)
          Digest::SHA1.hexdigest(public_key.to_der)
        end

        def rsa_encrypt_value(value, public_key)
          begin
            Base64.encode64(public_key.public_encrypt(value))
          rescue OpenSSL::PKey::RSAError => e
            raise EncryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

        def rsa_decrypt_value(value, key)
          begin
            key.private_decrypt(Base64.decode64(value.to_s))
          rescue OpenSSL::PKey::RSAError => e
            raise DecryptionFailure, "#{e.class.name}: #{e.to_s}"
          end
        end

        def rsa_encrypt_multi_key(value, public_keys)
          Mash.new(Hash[
            public_keys.map do |public_key|
              [
                node_key(public_key),
                rsa_encrypt_value(value, public_key),
              ]
            end
          ])
        end

        def rsa_decrypt_multi_key(enc_value, key)
          enc_value = enc_value[node_key(key.public_key)]
          rsa_decrypt_value(enc_value, key)
        end

        def data_can_be_decrypted_by_key?(enc_value, key)
          enc_value.has_key?(node_key(key.public_key))
        end

      end
    end
  end
end
