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
require 'chef/api_client'

describe Chef::EncryptedAttribute::EncryptedMash do
  extend ChefZero::RSpec
  before(:all) { clear_all_caches }

  when_the_chef_server 'is ready to rock!' do

    context '#update' do

      it 'calls RemoteClients#search_public_keys only once' do
        body = Chef::EncryptedAttribute.create(0)
        expect(Chef::EncryptedAttribute::RemoteClients)
          .to receive(:search_public_keys).once.and_return([])
        Chef::EncryptedAttribute.update(body)
      end

    end # context update
  end # when_the_chef_server is ready to rock!
end
