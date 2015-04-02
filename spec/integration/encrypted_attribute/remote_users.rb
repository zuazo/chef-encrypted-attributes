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

require 'integration_helper'

describe Chef::EncryptedAttribute::RemoteUsers do
  extend ChefZero::RSpec
  let(:remote_users_class) { Chef::EncryptedAttribute::RemoteUsers }
  before(:all) { clear_cache(:users) }

  when_the_chef_server 'is ready to rock!' do
    before { @users = (1..3).step.map { |n| chef_create_user("user#{n}") } }
    after { @users.each(&:destroy) }

    context '#get_public_keys' do
      it 'returns empty array by default' do
        expect(remote_users_class.get_public_keys).to eql([])
      end

      it 'returns all users with "*"' do
        expect(remote_users_class.get_public_keys('*').count).to eql(3 + 1)
      end

      it 'returns only public keys specified' do
        expect(
          remote_users_class.get_public_keys(%w(user1 user2)).count
        ).to eql(2)
      end

      it 'returns valid public keys' do
        pkey_pem = remote_users_class.get_public_keys(['user1'])[0]
        expect(pkey_pem).to be_a(String)
        pkey = create_ssl_key(pkey_pem)
        expect(pkey.public?).to be_truthy
        expect(pkey.private?).to be_falsey
      end

      it 'throws an error if the user is not found' do
        expect { remote_users_class.get_public_keys(%w(unknown1)) }
          .to raise_error(Chef::EncryptedAttribute::UserNotFound)
      end
    end # context #get_public_keys
  end # when_the_chef_server is ready to rock!
end
