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

describe Chef::EncryptedAttribute::RemoteNodes do
  extend ChefZero::RSpec
  let(:remote_nodes_class) { Chef::EncryptedAttribute::RemoteNodes }
  before(:all) { Chef::EncryptedAttribute::RemoteNodes.cache.clear }

  when_the_chef_server 'is ready to rock!' do
    before do
      # load the default clients
      @nodes = []
      @public_keys = []

      @node1, @node1_client = chef_create_node('node1') do |node|
        node.run_list << 'role[webapp]'
      end
      @nodes << @node1
      @public_keys << @node1_client.public_key

      @node2, @node2_client = chef_create_node('node2') do |node|
        node.run_list << 'role[ftp]'
      end
      @nodes << @node2
      @public_keys << @node2_client.public_key
    end
    after do
      @node1_client.destroy
      @node1.destroy
      @node2_client.destroy
      @node2.destroy
    end

    context '#search_public_keys' do
      it 'gets all client public_keys by default' do
        expect(remote_nodes_class.search_public_keys.sort)
          .to eql(@public_keys.sort)
      end

      context 'with node[public_key] set' do
        before do
          Chef::EncryptedAttribute::RemoteNodes.cache.clear
          @node3 = Chef::Node.new
          @node3.name('node3')
          @node3.set['public_key'] = 'pubkey3'
          @node3.save
          @node3_client = Chef::ApiClient.new
          @node3_client.name(@node3.name)
          @node3_client.public_key(@node3_client.save['public_key'])
        end
        after do
          @node3_client.destroy
          @node3.destroy
        end

        it 'uses node[public_key] attribute' do
          public_keys = @public_keys + [@node3['public_key']]
          expect(remote_nodes_class.search_public_keys.sort)
            .to eql(public_keys.sort)
        end
      end # context with node[public_key] set

      it 'reads the correct clients when a search query is passed as arg' do
        query = 'role:webapp'
        expect(remote_nodes_class.search_public_keys(query))
          .to eql([@node1_client.public_key])
      end

      it 'returns empty array for empty search results' do
        query = 'this_will_return_no_results:true'
        expect(remote_nodes_class.search_public_keys(query).sort).to eql([])
      end
    end # context #search_public_keys
  end # when_the_chef_server is ready to rock!
end
