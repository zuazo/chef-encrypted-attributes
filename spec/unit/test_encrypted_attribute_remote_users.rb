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
  before do
    @RemoteUsers = Chef::EncryptedAttribute::RemoteUsers
    Chef::Config[:chef_server_url] = 'https://api.opscode.com/organizations/opscode'
    user_list = {}
    @users = (0..2).step.map do |n|
      user = Chef::User.new
      user.name("user#{n}")
      user.public_key(OpenSSL::PKey::RSA.new(128).public_key.to_pem)
      user_list[user.name] = "#{Chef::Config[:chef_server_url]}/users/#{user.name}"
      user
    end
    Chef::User.stub(:load).and_return(@users[0])
    Chef::User.stub(:list).and_return(user_list)
  end

  describe '#get_public_keys' do

    it 'should return empty array by default' do
      @RemoteUsers.get_public_keys.should eql([])
    end

    it 'should return all users with "*"' do
      @RemoteUsers.get_public_keys('*').count.should eql(@users.count)
    end

    it 'should return only public keys specified' do
      @RemoteUsers.get_public_keys([ 'user0', 'user1' ] ).count.should eql(2)
    end

    [
      'bad-user-list',
      true, false, Hash.new, Object.new,
    ].each do |bad_users|

      it "should thrown an ArgumentError for user list of kind #{bad_users.class.name} (#{bad_users.inspect})" do
        lambda { @RemoteUsers.get_public_keys(bad_users) }.should raise_error(ArgumentError)
      end

    end # each do |bad_users|

    it 'should return valid public keys' do
      pkey_pem = @RemoteUsers.get_public_keys([ 'user0' ])[0]
      pkey_pem.should be_a(String)
      pkey = OpenSSL::PKey::RSA.new(pkey_pem)
      pkey.public?.should be_true
      pkey.private?.should be_false
    end

    {
      '403' => Chef::EncryptedAttribute::NoAdminPrivileges,
      '404' => Chef::EncryptedAttribute::UserNotFound,
      'anything_else' => Net::HTTPServerException,
    }.each do |code, exception|

      it "should throw an #{exception.to_s} exception if the server returns a #{code} code" do
        Chef::User.stub(:load) do
          raise Net::HTTPServerException.new('Net::HTTPServerException',
            Net::HTTPResponse.new('1.1', code, 'Net::HTTPResponse')
          )
        end
        lambda do
          @RemoteUsers.get_public_keys([ 'random_user' ] )
        end.should raise_error(exception)
      end

    end # each do |code, exception|

  end # describe #get_public_keys

end
