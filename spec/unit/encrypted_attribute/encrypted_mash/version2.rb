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

require 'spec_helper'

describe Chef::EncryptedAttribute::EncryptedMash::Version2,
         ruby_gte_20_and_openssl_gte_101: true do
  let(:encrypted_mash_class) { Chef::EncryptedAttribute::EncryptedMash }
  let(:encrypted_mash_version2_class) do
    Chef::EncryptedAttribute::EncryptedMash::Version2
  end
  let(:key1) { create_ssl_key }
  let(:key2) { create_ssl_key }

  context '#new' do

    it 'creates an EncryptedMash::Version2 object without errors' do
      expect { encrypted_mash_version2_class.new }.not_to raise_error
    end

    it 'sets the CHEF_TYPE key' do
      o = encrypted_mash_version2_class.new
      expect(o[encrypted_mash_class::CHEF_TYPE])
        .to eql(encrypted_mash_class::CHEF_TYPE_VALUE)
    end

    it 'sets the JSON_CLASS key' do
      o = encrypted_mash_version2_class.new
      expect(o[encrypted_mash_class::JSON_CLASS])
        .to eql(encrypted_mash_version2_class.to_s)
    end

    it 'throws an error if ruby does not support GCM' do
      allow(OpenSSL::Cipher).to receive(:method_defined?).with(:auth_data=)
        .and_return(false)
      expect { encrypted_mash_version2_class.new }
        .to raise_error(
          Chef::EncryptedAttribute::RequirementsFailure, /requires Ruby/
        )
    end

    it 'throws an error if OpenSSL does not support GCM' do
      allow(OpenSSL::Cipher).to receive(:ciphers).and_return([])
      expect { encrypted_mash_version2_class.new }
        .to raise_error(
          Chef::EncryptedAttribute::RequirementsFailure, /requires an OpenSSL/
        )
    end

  end # context #new

  context '#encrypt and #can_be_decrypted_by?' do

    it 'encrypts a value passing a OpenSSL::PKey::RSA key' do
      body = encrypted_mash_version2_class.new
      expect(body.can_be_decrypted_by?(key1)).to eql(false)
      body.encrypt('value1', key1.public_key)
      expect(body.can_be_decrypted_by?(key1)).to eql(true)
    end

    it 'encrypts a value passing a PEM String key' do
      body = encrypted_mash_version2_class.new
      expect(body.can_be_decrypted_by?(key1)).to eql(false)
      body.encrypt('value1', key1.public_key.to_pem)
      expect(body.can_be_decrypted_by?(key1)).to eql(true)
    end

    it 'encrypts a value passing a OpenSSL::PKey::RSA array' do
      keys = [key1, key2]
      body = encrypted_mash_version2_class.new
      expect(body.can_be_decrypted_by?(keys)).to eql(false)
      body.encrypt('value1', keys.map(&:public_key))
      expect(body.can_be_decrypted_by?(keys)).to eql(true)
    end

    it 'encrypts a value passing a Strings array' do
      keys = [key1, key2]
      body = encrypted_mash_version2_class.new
      expect(body.can_be_decrypted_by?(keys)).to eql(false)
      body.encrypt('value1', keys.map { |k| k.public_key.to_pem })
      expect(body.can_be_decrypted_by?(keys)).to eql(true)
    end

    it 'throws an InvalidKey error if the key is invalid' do
      body = encrypted_mash_version2_class.new
      expect { body.encrypt('value1', 'invalid-key') }
        .to raise_error(
          Chef::EncryptedAttribute::InvalidKey,
          /The provided key is invalid:/
        )
    end

    it 'throws an InvalidKey error if the public key is missing' do
      allow_any_instance_of(OpenSSL::PKey::RSA).to receive(:public?)
        .and_return(false)
      body = encrypted_mash_version2_class.new
      expect { body.encrypt('value1', key1.public_key) }
        .to raise_error(Chef::EncryptedAttribute::InvalidPublicKey)
    end

    it 'throws an error if there is an RSA Error' do
      # Will raise "OpenSSL::PKey::RSAError: data too large for key size" on
      # encryption
      key = create_ssl_key(32)
      body = encrypted_mash_version2_class.new
      expect { body.encrypt('value1', key) }
        .to raise_error(Chef::EncryptedAttribute::EncryptionFailure)
    end

    it 'throws an error if the encryption fails' do
      body = encrypted_mash_version2_class.new
      expect_any_instance_of(OpenSSL::Cipher)
        .to receive(:update).and_raise(OpenSSL::Cipher::CipherError.new(''))
      expect { body.encrypt('value1', key1) }
        .to raise_error(
          Chef::EncryptedAttribute::EncryptionFailure,
          /OpenSSL::Cipher::CipherError/
        )
    end

  end # context #encrypt and #can_be_decrypted_by?

  context '#decrypt' do

    [
      true, false, 0, 'value1', [], {}
    ].each do |v|
      it "decrypts an encrypted #{v}" do
        body = encrypted_mash_version2_class.new
        body.encrypt(v, key1.public_key)
        expect(body.decrypt(key1)).to eql(v)
      end
    end

    it 'throws an InvalidKey error if the private key is invalid' do
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', key1.public_key)
      expect { body.decrypt('invalid-private-key') }
        .to raise_error(
          Chef::EncryptedAttribute::InvalidKey,
          /The provided key is invalid:/
        )
    end

    it 'throws an InvalidKey error if only the public key is provided' do
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', key1.public_key)
      expect { body.decrypt(key1.public_key) }
        .to raise_error(
          Chef::EncryptedAttribute::InvalidKey,
          Regexp.new(
            'The provided key for decryption is invalid, a valid public and '\
            'private key is required\.'
          )
        )
    end

    it 'throws a DecryptionFailure error if the private key cannot decrypt '\
       'it' do
      bad_key = key2
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', key1.public_key)
      expect { body.decrypt(bad_key) }
        .to raise_error(
          Chef::EncryptedAttribute::DecryptionFailure,
          /Attribute data cannot be decrypted by the provided key\./
        )
    end

    it 'throws an error if the authentication tag does not match' do
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', key1.public_key)
      body['encrypted_data']['auth_tag'] = 'bogus_auth_tag'
      expect { body.decrypt(key1) }
        .to raise_error(
          Chef::EncryptedAttribute::DecryptionFailure,
          /OpenSSL::Cipher::CipherError/
        )
    end

    it 'throws an error if the decryption fails' do
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', key1.public_key)
      expect_any_instance_of(OpenSSL::Cipher)
        .to receive(:update).and_raise(OpenSSL::Cipher::CipherError.new(''))
      expect { body.decrypt(key1) }
        .to raise_error(
          Chef::EncryptedAttribute::DecryptionFailure,
          /OpenSSL::Cipher::CipherError/
        )
    end

  end # context #decrypt

  context '#needs_update?' do

    it 'returns false if there no new keys' do
      keys = [key1.public_key]
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', keys)
      expect(body.needs_update?(keys)).to be_falsey
    end

    it 'returns true if there are new keys' do
      keys = [key1.public_key]
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', keys)
      keys.push(key2.public_key)
      expect(body.needs_update?(keys)).to be_truthy
    end

    it 'returns true if some keys are removed' do
      keys = [key1.public_key, key2.public_key]
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', keys)
      expect(body.needs_update?(keys[0])).to be_truthy
    end

    it 'returns false if the keys are the same, but in different order or '\
       'format' do
      keys = [key1.public_key, key2.public_key]
      body = encrypted_mash_version2_class.new
      body.encrypt('value1', keys)
      expect(body.needs_update?([keys[1], keys[0].to_pem])).to be_falsey
    end

  end # context #needs_update?
end # describe Chef::EncryptedAttribute::EncryptedMash::Version2
