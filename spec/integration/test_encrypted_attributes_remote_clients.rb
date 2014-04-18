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

describe Chef::EncryptedAttribute::RemoteClients do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      @RemoteClients = Chef::EncryptedAttribute::RemoteClients

      # load the default clients
      @clients = Chef::ApiClient.list.keys.each.map do |c|
        Chef::ApiClient.load(c)
      end

      # create one admin client
      @admin1 = Chef::ApiClient.new
      @admin1.name('admin1')
      @admin1.admin(true)
      @admin1.save
      @admin1 = Chef::ApiClient.load(@admin1.name) # reload the public_key
      @clients << @admin1

      # create one normal client like a node
      @client1 = Chef::ApiClient.new
      @client1.name('client1')
      @client1.admin(false)
      @client1.save
      @client1 = Chef::ApiClient.load(@client1.name) # reload the public_key
      @clients << @client1

      # Chef::EncryptedAttribute.config.partial_search(false)
    end
    after do
      @admin1.destroy
      @client1.destroy
    end

    context '#get_public_keys' do

      it 'should get all client public_keys by default' do
        @RemoteClients.get_public_keys.sort.should eql(@clients.map { |c| c.public_key }.sort)
      end

      it 'should read the correct clients when a search query is passed as arg' do
        query = 'admin:true'
        @admins = @clients.reject { |c| !c.admin }
        @RemoteClients.get_public_keys(query).sort.should eql(@admins.map { |c| c.public_key }.sort)
      end

      it 'should return empty array for empty search results' do
        query = 'this_will_return_no_results:true'
        @RemoteClients.get_public_keys(query).sort.should eql([])
      end

    end # context #get_public_keys

  end # when_the_chef_server is ready to rock!
end
