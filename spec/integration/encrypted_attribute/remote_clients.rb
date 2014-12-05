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
  before(:all) do
    Chef::EncryptedAttribute::RemoteClients.cache.clear
  end

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
      @admin1.public_key(@admin1.save['public_key'])
      @clients << @admin1

      # create one normal client like a node
      @client1 = Chef::ApiClient.new
      @client1.name('client1')
      @client1.admin(false)
      @client1.public_key(@client1.save['public_key'])
      @clients << @client1
    end
    after do
      @admin1.destroy
      @client1.destroy
    end

    context '#get_public_key' do

      it 'returns client public key' do
        expect(@RemoteClients.get_public_key('admin1')).to eq(@admin1.public_key)
      end

      it 'throws an error if the user is not found' do
        expect { @RemoteClients.get_public_key('unknown') }.to raise_error(Chef::EncryptedAttribute::ClientNotFound)
      end

    end

    context '#search_public_keys' do

      it 'gets all client public_keys by default' do
        expect(@RemoteClients.search_public_keys.sort).to eql(@clients.map { |c| c.public_key }.sort)
      end

      it 'reads the correct clients when a search query is passed as arg' do
        query = 'admin:true'
        @admins = @clients.reject { |c| !c.admin }
        expect(@RemoteClients.search_public_keys(query).sort).to eql(@admins.map { |c| c.public_key }.sort)
      end

      it 'returns empty array for empty search results' do
        query = 'this_will_return_no_results:true'
        expect(@RemoteClients.search_public_keys(query).sort).to eql([])
      end

    end # context #search_public_keys

  end # when_the_chef_server is ready to rock!
end
