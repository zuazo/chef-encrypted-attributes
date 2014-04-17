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

require 'integration_helper'

describe Chef::EncryptedAttribute::RemoteUsers do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      @RemoteUsers = Chef::EncryptedAttribute::RemoteUsers
      @users = (0..2).step.map do |n|
        user = Chef::User.new
        user.name("user#{n}")
        user.save
        user
      end
    end

    context '#get_public_keys' do

      it 'should return empty array by default' do
        @RemoteUsers.get_public_keys.should eql([])
      end

      it 'should return all users with "*"' do
        @RemoteUsers.get_public_keys('*').count.should eql(3 + 1)
      end

      it 'should return only public keys specified' do
        @RemoteUsers.get_public_keys([ 'user0', 'user1' ] ).count.should eql(2)
      end

      it 'should return valid public keys' do
        pkey_pem = @RemoteUsers.get_public_keys([ 'user0' ])[0]
        pkey_pem.should be_a(String)
        pkey = OpenSSL::PKey::RSA.new(pkey_pem)
        pkey.public?.should be_true
        pkey.private?.should be_false
      end

      it 'should throw an error if the user is not found' do
        lambda { @RemoteUsers.get_public_keys([ 'unknown1' ] ) }.should raise_error(Chef::EncryptedAttribute::UserNotFound)
      end

    end # context #get_public_keys

  end # when_the_chef_server is ready to rock!
end
