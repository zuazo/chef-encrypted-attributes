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

class EncryptedMashVersionBadCipher < Chef::EncryptedAttribute::EncryptedMash::Version1
  SYMM_ALGORITHM = 'aes-256-cbc'
end

describe Chef::EncryptedAttribute::EncryptedMash::Version1 do
  before(:all) do
    @key1 = OpenSSL::PKey::RSA.new(2048)
    @key2 = OpenSSL::PKey::RSA.new(2048)
    @EncryptedMashBase = Chef::EncryptedAttribute::EncryptedMash::Base
    @EncryptedMashVersion1 = Chef::EncryptedAttribute::EncryptedMash::Version1
  end

  context '#new' do

    it 'should create an EncryptedMash::Version1 object without errors' do
      lambda { @EncryptedMashVersion1.new }.should_not raise_error
    end

    it 'should set the CHEF_TYPE key' do
      o = @EncryptedMashVersion1.new
      o[@EncryptedMashBase::CHEF_TYPE].should eql(@EncryptedMashBase::CHEF_TYPE_VALUE)
    end

    it 'should set the JSON_CLASS key' do
      o = @EncryptedMashVersion1.new
      o[@EncryptedMashBase::JSON_CLASS].should eql(@EncryptedMashVersion1.to_s)
    end

  end # context #new

  context '#encrypt and #can_be_decrypted_by?' do

    it 'should encrypt a value passing a OpenSSL::PKey::RSA key' do
      body = @EncryptedMashVersion1.new
      body.can_be_decrypted_by?(@key1).should eql(false)
      body.encrypt('value1', @key1.public_key)
      body.can_be_decrypted_by?(@key1).should eql(true)
    end

    it 'should encrypt a value passing a PEM String key' do
      body = @EncryptedMashVersion1.new
      body.can_be_decrypted_by?(@key1).should eql(false)
      body.encrypt('value1', @key1.public_key.to_pem)
      body.can_be_decrypted_by?(@key1).should eql(true)
    end

    it 'should encrypt a value passing a OpenSSL::PKey::RSA array' do
      keys = [ @key1, @key2 ]
      body = @EncryptedMashVersion1.new
      body.can_be_decrypted_by?(keys).should eql(false)
      body.encrypt('value1', keys.map { |k| k.public_key })
      body.can_be_decrypted_by?(keys).should eql(true)
    end

    it 'should encrypt a value passing a Strings array' do
      keys = [ @key1, @key2 ]
      body = @EncryptedMashVersion1.new
      body.can_be_decrypted_by?(keys).should eql(false)
      body.encrypt('value1', keys.map { |k| k.public_key.to_pem })
      body.can_be_decrypted_by?(keys).should eql(true)
    end

    it 'should throw an InvalidPrivateKey error if the key is invalid' do
      body = @EncryptedMashVersion1.new
      lambda { body.encrypt('value1', 'invalid-key') }.should raise_error(Chef::EncryptedAttribute::InvalidPrivateKey, /The provided key is invalid:/)
    end

    it 'should throw an InvalidPrivateKey error if the public key is missing' do
      OpenSSL::PKey::RSA.any_instance.stub(:public?).and_return(false)
      body = @EncryptedMashVersion1.new
      lambda { body.encrypt('value1', @key1.public_key) }.should raise_error(Chef::EncryptedAttribute::InvalidPublicKey)
    end

    it 'should throw an error if there is an RSA Error' do
      key = OpenSSL::PKey::RSA.new(32) # will raise "OpenSSL::PKey::RSAError: data too large for key size" on encryption
      body = @EncryptedMashVersion1.new
      lambda { body.encrypt('value1', key) }.should raise_error(Chef::EncryptedAttribute::EncryptionFailure)
    end

    it 'should throw an error if the encryption fails' do
      body = @EncryptedMashVersion1.new
      OpenSSL::Cipher.any_instance.should_receive(:update).and_raise(OpenSSL::Cipher::CipherError.new(''))
      lambda { body.encrypt('value1', @key1) }.should raise_error(Chef::EncryptedAttribute::EncryptionFailure, /OpenSSL::Cipher::CipherError/)
    end

    it 'should throw an error if the hmac generation fails' do
      body = @EncryptedMashVersion1.new
      OpenSSL::HMAC.should_receive(:digest).and_raise(OpenSSL::HMACError)
      lambda { body.encrypt('value1', @key1) }.should raise_error(Chef::EncryptedAttribute::MessageAuthenticationFailure, /OpenSSL::HMACError/)
    end

  end # context #encrypt and #can_be_decrypted_by?

  context '#decrypt' do

    [
      true, false, 0, 'value1', [], {}
    ].each do |v|
      it "should decrypt an encrypted #{v}" do
        body = @EncryptedMashVersion1.new
        body.encrypt(v, @key1.public_key)
        body.decrypt(@key1).should eql(v)
      end
    end

    it 'should throw an InvalidPrivateKey error if the private key is invalid' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      lambda { body.decrypt('invalid-private-key') }.should raise_error(Chef::EncryptedAttribute::InvalidPrivateKey, /The provided key is invalid:/)
    end

    it 'should throw an InvalidPrivateKey error if only the public key is provided' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      lambda { body.decrypt(@key1.public_key) }.should raise_error(Chef::EncryptedAttribute::InvalidPrivateKey, /The provided key for decryption is invalid, a valid public and private key is required\./)
    end

    it 'should throw a DecryptionFailure error if the private key cannot decrypt it' do
      bad_key = @key2
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      lambda { body.decrypt(bad_key) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
    end

    %w{cipher iv data}.each do |data_key|
      it "should throw an HMAC error if the \"#{data_key}\" key does not match" do
        body = @EncryptedMashVersion1.new
        body.encrypt('value1', @key1.public_key)
        body['encrypted_data'][data_key] = 'bad-key-data'
        lambda { body.decrypt(@key1) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /invalid hmac/)
      end
    end

    it 'should throw a DecryptionFailure error if the HMAC does not match' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      body['hmac'] = 'bad-hmac'
      lambda { body.decrypt(@key1) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /invalid hmac/)
    end

    it 'should throw a DecryptionFailure error if the algorithm is unknown' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      body['hmac'] = 'bad-hmac'
      lambda { body.decrypt(@key1) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /invalid hmac/)
    end

    it 'should throw an error if the decryption fails' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      OpenSSL::Cipher.any_instance.should_receive(:update).and_raise(OpenSSL::Cipher::CipherError.new(''))
      lambda { body.decrypt(@key1) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /OpenSSL::Cipher::CipherError/)
    end

    it 'should throw an error if the hmac generation for checking fails' do
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', @key1.public_key)
      OpenSSL::HMAC.should_receive(:digest).and_raise(OpenSSL::HMACError)
      lambda { body.decrypt(@key1) }.should raise_error(Chef::EncryptedAttribute::MessageAuthenticationFailure, /OpenSSL::HMACError/)
    end

  end # context #decrypt

  context '#needs_update?' do

    it 'should return false if there no new keys' do
      keys = [ @key1.public_key ]
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', keys )
      body.needs_update?(keys).should be_false
    end

    it 'should return true if there are new keys' do
      keys = [ @key1.public_key ]
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', keys)
      keys.push(@key2.public_key)
      body.needs_update?(keys).should be_true
    end

    it 'should return true if some keys are removed' do
      keys = [ @key1.public_key, @key2.public_key ]
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', keys)
      body.needs_update?(keys[0]).should be_true
    end

    it 'should return false if the keys are the same, but in different order or format' do
      keys = [ @key1.public_key, @key2.public_key ]
      body = @EncryptedMashVersion1.new
      body.encrypt('value1', keys)
      body.needs_update?([ keys[1], keys[0].to_pem ]).should be_false
    end

  end # context #needs_update?

end # describe Chef::EncryptedAttribute::EncryptedMash::Version1
