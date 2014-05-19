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

describe Chef::EncryptedAttribute::RemoteClients do
  before do
    Chef::EncryptedAttribute::RemoteClients.cache.clear

    @RemoteClients = Chef::EncryptedAttribute::RemoteClients
    allow(@RemoteClients).to receive(:search)
  end

  it 'should include EncryptedAttribute::SearchHelper methods' do
    expect(@RemoteClients).to be_kind_of(Chef::EncryptedAttribute::SearchHelper)
  end

  describe '#get_public_keys' do
    before(:all) do
      Chef::EncryptedAttribute::RemoteClients.cache.max_size(20)
    end
    before do
      @public_keys = [
        OpenSSL::PKey::RSA.new(128).public_key.to_pem,
        OpenSSL::PKey::RSA.new(128).public_key.to_pem,
      ]
      @clients = @public_keys.map { |x| { 'public_key' => x } }
    end

    it 'should get client public_keys using SearchHelper' do
      allow(@RemoteClients).to receive(:search).and_return(@clients)
      expect(@RemoteClients.get_public_keys).to eql(@public_keys)
    end

    it 'should return empty array for empty search results' do
      allow(@RemoteClients).to receive(:search).and_return({})
      expect(@RemoteClients.get_public_keys).to eql([])
    end

    it 'should do a search with the correct arguments' do
      query = 'admin:true'
      expect(@RemoteClients).to receive(:search).once.with(
        :client,
        query,
        { 'public_key' => [ 'public_key' ] },
        1000,
        true
      ).and_return(@clients)
      @RemoteClients.get_public_keys(query)
    end

    it 'should do "*:*" search by default' do
      expect(@RemoteClients).to receive(:search).with(
        :client,
        '*:*',
        { 'public_key' => [ 'public_key' ] },
        1000,
        true
      ).and_return(@clients)
      @RemoteClients.get_public_keys
    end

    it 'should cache search results for multiple calls' do
      query = 'admin:true'
      expect(@RemoteClients).to receive(:search).once.with(
        :client,
        query,
        { 'public_key' => [ 'public_key' ] },
        1000,
        true
      ).and_return(@clients)

      @RemoteClients.get_public_keys(query)
      @RemoteClients.get_public_keys(query) # cached
    end

  end # describe #get_public_keys

end
