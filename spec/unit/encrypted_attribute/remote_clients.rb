# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
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

describe Chef::EncryptedAttribute::RemoteClients do
  let(:remote_clients_class) { Chef::EncryptedAttribute::RemoteClients }
  before do
    clear_cache(:clients)

    allow(remote_clients_class).to receive(:search)
  end

  it 'includes EncryptedAttribute::SearchHelper methods' do
    expect(remote_clients_class)
      .to be_kind_of(Chef::EncryptedAttribute::SearchHelper)
  end

  describe '#get_public_key' do
    it 'gets client public key' do
      fake_client = Chef::ApiClient.new
      allow(fake_client).to receive(:public_key).and_return('OK')
      expect(Chef::ApiClient)
        .to receive(:load).with('node1').and_return(fake_client)
      expect(remote_clients_class.get_public_key('node1')).to eq('OK')
    end

    {
      '404' => Chef::EncryptedAttribute::ClientNotFound,
      'anything_else' => Net::HTTPServerException
    }.each do |code, exception|
      it "throws an #{exception} exception if the server returns a "\
         "#{code} code" do
        allow(Chef::ApiClient).to receive(:load) do
          fail Net::HTTPServerException.new(
            'Net::HTTPServerException',
            Net::HTTPResponse.new('1.1', code, 'Net::HTTPResponse')
          )
        end
        expect do
          remote_clients_class.get_public_key('random_client')
        end.to raise_error(exception)
      end
    end
  end # #get_public_key

  describe '#search_public_keys' do
    let(:public_keys) do
      [
        create_ssl_key.public_key.to_pem,
        create_ssl_key.public_key.to_pem
      ]
    end
    let(:clients) { public_keys.map { |x| { 'public_key' => x } } }
    before(:all) { cache_size(:clients, 20) }

    it 'gets client public_keys using SearchHelper' do
      allow(remote_clients_class).to receive(:search).and_return(clients)
      expect(remote_clients_class.search_public_keys).to eql(public_keys)
    end

    it 'returns empty array for empty search results' do
      allow(remote_clients_class).to receive(:search).and_return({})
      expect(remote_clients_class.search_public_keys).to eql([])
    end

    it 'does a search with the correct arguments' do
      query = 'admin:true'
      expect(remote_clients_class).to receive(:search).once.with(
        :client,
        query,
        { 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(clients)
      remote_clients_class.search_public_keys(query)
    end

    it 'does "*:*" search by default' do
      expect(remote_clients_class).to receive(:search).with(
        :client,
        '*:*',
        { 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(clients)
      remote_clients_class.search_public_keys
    end

    it 'caches search results for multiple calls' do
      query = 'admin:true'
      expect(remote_clients_class).to receive(:search).once.with(
        :client,
        query,
        { 'public_key' => %w(public_key) },
        1000,
        true
      ).and_return(clients)

      remote_clients_class.search_public_keys(query)
      remote_clients_class.search_public_keys(query) # cached
    end
  end # describe #search_public_keys
end
