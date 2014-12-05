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

describe Chef::EncryptedAttribute::RemoteUsers do
  before(:all) do
    Chef::EncryptedAttribute::RemoteUsers.cache.max_size(20)
  end
  before do
    Chef::EncryptedAttribute::RemoteUsers.cache.clear

    @RemoteUsers = Chef::EncryptedAttribute::RemoteUsers
    @prev_chef_server = Chef::Config[:chef_server_url]
    Chef::Config[:chef_server_url] = 'https://api.opscode.com/organizations/opscode'
    user_list = {}
    @users = (0..2).step.map do |n|
      user = Chef::User.new
      user.name("user#{n}")
      user.public_key(OpenSSL::PKey::RSA.new(128).public_key.to_pem)
      user_list[user.name] = "#{Chef::Config[:chef_server_url]}/users/#{user.name}"
      user
    end
    allow(Chef::User).to receive(:load).and_return(@users[0])
    allow(Chef::User).to receive(:list).and_return(user_list)
  end
  after(:all) do
    Chef::Config[:chef_server_url] = @prev_chef_server if @prev_chef_server.kind_of?(String)
  end

  describe '#get_public_keys' do

    it 'returns empty array by default' do
      expect(@RemoteUsers.get_public_keys).to eql([])
    end

    it 'returns all users with "*"' do
      expect(@RemoteUsers.get_public_keys('*').count).to eql(@users.count)
    end

    it 'returns cached users with multiples "*"' do
      expect(@RemoteUsers).to receive(:get_all_public_keys).once.and_return('users1')
      expect(@RemoteUsers.get_public_keys('*')).to eql('users1')
      expect(@RemoteUsers.get_public_keys('*')).to eql('users1') # cached
    end

    it 'returns only public keys specified' do
      expect(@RemoteUsers.get_public_keys([ 'user0', 'user1' ] ).count).to eql(2)
    end

    it 'returns cached public keys on multiple calls' do
      expect(Chef::User).to receive(:load).with('user0').once.and_return(@users[0])
      expect(@RemoteUsers.get_public_keys([ 'user0' ] )).to eql([ @users[0].public_key ])
      expect(@RemoteUsers.get_public_keys([ 'user0' ] )).to eql([ @users[0].public_key ]) # cached
    end

    [
      'bad-user-list',
      true, false, Hash.new, Object.new,
    ].each do |bad_users|

      it "throws an ArgumentError for user list of kind #{bad_users.class.name} (#{bad_users.inspect})" do
        expect { @RemoteUsers.get_public_keys(bad_users) }.to raise_error(ArgumentError)
      end

    end # each do |bad_users|

    it 'returns valid public keys' do
      pkey_pem = @RemoteUsers.get_public_keys([ 'user0' ])[0]
      expect(pkey_pem).to be_a(String)
      pkey = OpenSSL::PKey::RSA.new(pkey_pem)
      expect(pkey.public?).to be_truthy
      expect(pkey.private?).to be_falsey
    end

    {
      '403' => Chef::EncryptedAttribute::InsufficientPrivileges,
      '404' => Chef::EncryptedAttribute::UserNotFound,
      'anything_else' => Net::HTTPServerException,
    }.each do |code, exception|

      it "throws an #{exception.to_s} exception if the server returns a #{code} code" do
        allow(Chef::User).to receive(:load) do
          raise Net::HTTPServerException.new('Net::HTTPServerException',
            Net::HTTPResponse.new('1.1', code, 'Net::HTTPResponse')
          )
        end
        expect do
          @RemoteUsers.get_public_keys([ 'random_user' ] )
        end.to raise_error(exception)
      end

    end # each do |code, exception|

  end # describe #get_public_keys

end
