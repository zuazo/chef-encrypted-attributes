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
  let(:search_helper_class) { Chef::EncryptedAttribute::SearchHelper }
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do

    context '#search' do
      before do
        @default_clients = Chef::ApiClient.list.keys.map do |c|
          Chef::ApiClient.load(c)
        end

        @nodes = []
        @node_clients = []
        (1..4).step.map do |n|
          node, node_client = chef_create_node("node#{n}") do |node|
            node.set['some'][:deep] = "attr#{n}"
          end
          @nodes << node
          @node_clients << node_client
        end
        @new_clients = (1..2).step.map { |c| chef_create_client("client#{c}") }
      end
      after do
        @nodes.each(&:destroy)
        @node_clients.each(&:destroy)
        @new_clients.each(&:destroy)
      end

      [true, false].each do |partial_search|
        context "with partial_search=#{partial_search}" do

          it 'searches node attributes without errors' do
            expect(search_helper_class.search(
              :node, 'name:*', { 'value' => %w(some deep) }, 1000,
              partial_search
            )).to eql(
              @nodes.map { |n| { 'value' => n['some']['deep'] } }
            )
          end

          it 'searches all client public_keys without errors' do
            # load the default clients
            all_clients = @default_clients + @node_clients + @new_clients
            expect(search_helper_class.search(
              :client, '*:*', { 'key' => %w(public_key) }, 1000, partial_search
            ).count).to eql(all_clients.count)

            expect(search_helper_class.search(
              :client, '*:*', { 'key' => %w(public_key) }, 1000, partial_search
            ).map { |x| x['key'] }.sort)
              .to eql(all_clients.map(&:public_key).sort)
          end

          it 'searches some client public_keys without errors' do
            search_ary = @new_clients.map { |c| "name:#{c.name}" }
            expect(search_helper_class.search(
              :client, search_ary, { 'key' => %w(public_key) }, 1000,
              partial_search
            )).to eql(
              @new_clients.map { |n| { 'key' => n.public_key } }
            )
          end

          it 'returns empty results without errors' do
            expect(search_helper_class.search(
              :client, 'empty-result:true', { 'key' => %w(public_key) }, 1000,
              partial_search
            )).to eql([])
          end

          it 'returns empty results without bad types' do
            expect(search_helper_class.search(
              :bad_type, '*:*', { 'key' => %w(public_key) }, 1000,
              partial_search
            )).to eql([])
          end

          it 'throws an error for invalid keys' do
            expect do
              search_helper_class.search(
                :node, '*:*', { invalid: 'query' }, 1000, partial_search
              )
            end.to raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
          end

        end # context partial_search=?
      end # each do |partial_search|
    end # context #search
  end # when_the_chef_server is ready to rock!
end
