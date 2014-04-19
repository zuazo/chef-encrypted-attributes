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

describe Chef::EncryptedAttribute::SearchHelper do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      @SearchHelper = Chef::EncryptedAttribute::SearchHelper
    end

    context '#search' do
      before do
        @nodes = (1..4).step.map do |n|
          node = Chef::Node.new
          node.name("node#{n}")
          node.set['some'][:deep] = "attr#{n}"
          node.save
          node
        end
        # load the default clients
        @default_clients = Chef::ApiClient.list.keys.each.map do |c|
          Chef::ApiClient.load(c)
        end
        @new_clients = (1..2).step.map do |c|
          client = Chef::ApiClient.new
          client.name("client#{c}")
          client.admin(false)
          client.save
          client = Chef::ApiClient.load(client.name) # reload the public_key
          client
        end
      end
      after do
        @nodes.each { |n| n.destroy }
        @new_clients.each { |c| c.destroy }
      end

      [ true, false ].each do |partial_search|
        context "partial_search=#{partial_search}" do

          it 'should search node attributes without errors' do
            @SearchHelper.search(:node, 'name:*', { 'value' => [ 'some', 'deep' ] }, 1000, partial_search).should eql(
              @nodes.map { |n| { 'value' => n['some']['deep'] } }
            )
          end

          it 'should search all client public_keys without errors' do
            @SearchHelper.search(:client, '*:*', { 'key' => [ 'public_key' ] }, 1000, partial_search).should eql(
              (@default_clients + @new_clients).map { |n| { 'key' => n.public_key } }
            )
          end

          it 'should search some client public_keys without errors' do
            search_ary = @new_clients.map { |c| "name:#{c.name}" }
            @SearchHelper.search(:client, search_ary, { 'key' => [ 'public_key' ] }, 1000, partial_search).should eql(
              @new_clients.map { |n| { 'key' => n.public_key } }
            )
          end

          it 'should return empty results without errors' do
            @SearchHelper.search(:client, 'empty-result:true', { 'key' => [ 'public_key' ] }, 1000, partial_search).should eql([])
          end

          it 'should return empty results without bad types' do
            @SearchHelper.search(:bad_type, '*:*' , { 'key' => [ 'public_key' ] }, 1000, partial_search).should eql([])
          end

          it 'should throw an error for invalid keys' do
            lambda { @SearchHelper.search(:node, '*:*', { :invalid => 'query' }, 1000, partial_search) }.should raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
          end

        end # context partial_search=?

      end # each do |partial_search|

    end # context #search

  end # when_the_chef_server is ready to rock!
end
