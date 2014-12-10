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

describe Chef::EncryptedAttribute::RemoteUsers do
  let(:remote_users_class) { Chef::EncryptedAttribute::RemoteUsers }
  let(:users) do
    (0..2).step.map do |n|
      user = Chef::User.new
      user.name("user#{n}")
      user.public_key(create_ssl_key.public_key.to_pem)
      user
    end
  end
  let(:user_list) do
    users.each_with_object({}) do |user, memo|
      memo[user.name] =
        "#{Chef::Config[:chef_server_url]}/users/#{user.name}"
    end
  end
  before(:all) { cache_size(:users, 20) }
  before do
    clear_cache(:users)

    @prev_chef_server = Chef::Config[:chef_server_url]
    Chef::Config[:chef_server_url] =
      'https://api.opscode.com/organizations/opscode'
    allow(Chef::User).to receive(:load).and_return(users[0])
    allow(Chef::User).to receive(:list).and_return(user_list)
  end
  after(:all) do
    if @prev_chef_server.is_a?(String)
      Chef::Config[:chef_server_url] = @prev_chef_server
    end
  end

  describe '#get_public_keys' do

    it 'returns empty array by default' do
      expect(remote_users_class.get_public_keys).to eql([])
    end

    it 'returns all users with "*"' do
      expect(remote_users_class.get_public_keys('*').count).to eql(users.count)
    end

    it 'returns cached users with multiples "*"' do
      expect(remote_users_class)
        .to receive(:all_public_keys).once.and_return('users1')
      expect(remote_users_class.get_public_keys('*')).to eql('users1')
      expect(remote_users_class.get_public_keys('*')).to eql('users1') # cached
    end

    it 'returns only public keys specified' do
      expect(remote_users_class.get_public_keys(%w(user0 user1)).count)
        .to eql(2)
    end

    it 'returns cached public keys on multiple calls' do
      expect(Chef::User)
        .to receive(:load).with('user0').once.and_return(users[0])
      expect(remote_users_class.get_public_keys(%w(user0)))
        .to eql([users[0].public_key])
      expect(remote_users_class.get_public_keys(%w(user0)))
        .to eql([users[0].public_key]) # cached
    end

    [
      'bad-user-list', true, false, Hash.new, Object.new
    ].each do |bad_users|

      it 'throws an ArgumentError for user list of kind '\
         "#{bad_users.class.name} (#{bad_users.inspect})" do
        expect { remote_users_class.get_public_keys(bad_users) }
          .to raise_error(ArgumentError)
      end

    end # each do |bad_users|

    it 'returns valid public keys' do
      pkey_pem = remote_users_class.get_public_keys(%w(user0))[0]
      expect(pkey_pem).to be_a(String)
      pkey = create_ssl_key(pkey_pem)
      expect(pkey.public?).to be_truthy
      expect(pkey.private?).to be_falsey
    end

    {
      '403' => Chef::EncryptedAttribute::InsufficientPrivileges,
      '404' => Chef::EncryptedAttribute::UserNotFound,
      'anything_else' => Net::HTTPServerException
    }.each do |code, exception|

      it "throws an #{exception} exception if the server returns a "\
         "#{code} code" do
        allow(Chef::User).to receive(:load) do
          fail Net::HTTPServerException.new(
            'Net::HTTPServerException',
            Net::HTTPResponse.new('1.1', code, 'Net::HTTPResponse')
          )
        end
        expect { remote_users_class.get_public_keys(%w(random_user)) }
          .to raise_error(exception)
      end

    end # each do |code, exception|
  end # describe #get_public_keys
end
