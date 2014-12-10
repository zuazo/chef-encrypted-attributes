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
require 'chef/api_client'

describe Chef::EncryptedAttribute::RemoteNodes do
  let(:remote_nodes_class) { Chef::EncryptedAttribute::RemoteNodes }
  let(:remote_clients_class) { Chef::EncryptedAttribute::RemoteClients }
  before do
    clear_cache(:nodes)

    allow(remote_nodes_class).to receive(:search)
  end

  it 'includes EncryptedAttribute::SearchHelper methods' do
    expect(remote_nodes_class)
      .to be_kind_of(Chef::EncryptedAttribute::SearchHelper)
  end

  describe '#search_public_keys' do
    let(:keys) do
      {
        'node1' => create_ssl_key.public_key.to_pem,
        'node2' => create_ssl_key.public_key.to_pem
      }
    end
    let(:public_keys) { keys.values }
    let(:nodes) { keys.keys.map { |x| { 'name' => x } } }
    before(:all) { Chef::EncryptedAttribute::RemoteNodes.cache.max_size(20) }
    before do
      keys.each do |node, key|
        allow(remote_clients_class)
          .to receive(:get_public_key).with(node).and_return(key)
      end
    end

    it 'gets client public_keys using SearchHelper' do
      allow(remote_nodes_class).to receive(:search).and_return(nodes)
      expect(remote_nodes_class.search_public_keys).to eql(public_keys)
    end

    it 'returns empty array for empty search results' do
      allow(remote_nodes_class).to receive(:search).and_return({})
      expect(remote_nodes_class.search_public_keys).to eql([])
    end

    it 'does a search with the correct arguments' do
      query = 'role:webapp'
      expect(remote_nodes_class).to receive(:search).once.with(
        :node,
        query,
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)
      remote_nodes_class.search_public_keys(query)
    end

    it 'does "*:*" search by default' do
      expect(remote_nodes_class).to receive(:search).with(
        :node,
        '*:*',
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)
      remote_nodes_class.search_public_keys
    end

    it 'caches search results for multiple calls' do
      query = 'role:webapp'
      expect(remote_nodes_class).to receive(:search).once.with(
        :node,
        query,
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)

      remote_nodes_class.search_public_keys(query)
      remote_nodes_class.search_public_keys(query) # cached
    end

    it 'returns client public keys' do
      query = '*:*'
      expect(remote_nodes_class).to receive(:search).once.with(
        :node,
        query,
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)
      expect(remote_nodes_class.search_public_keys(query)).to eq(keys.values)
    end

    it 'returns node[public_key] attribute if exists' do
      query = '*:*'
      nodes = keys.keys.map { |x| { 'name' => x, 'public_key' => 'pubkey' } }
      expect(remote_nodes_class).to receive(:search).once.with(
        :node,
        query,
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)
      expect(remote_nodes_class.search_public_keys(query))
        .to eq(%w(pubkey pubkey))
    end

    it 'raises an error if forbidden' do
      query = '*:*'
      expect(remote_nodes_class).to receive(:search).once.with(
        :node,
        query,
        { 'name' => %w(name), 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(nodes)
      expect(Chef::EncryptedAttribute::RemoteClients)
        .to receive(:get_public_key).with(anything).and_raise(
          Net::HTTPServerException.new(
            'Net::HTTPServerException',
            Net::HTTPResponse.new('1.1', '403', 'Forbidden')
          )
        )
      expect { remote_nodes_class.search_public_keys(query) }.to raise_error(
        Chef::EncryptedAttribute::InsufficientPrivileges,
        /encrypted_attributes::expose_key/
      )
    end

  end # describe #search_public_keys
end
