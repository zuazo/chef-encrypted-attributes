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

require 'benchmark_helper'

describe 'Chef::EncryptedAttribute Benchmarks' do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    let(:node) do
      node = Chef::Node.new
      node.name(Chef::Config[:node_name])
      node
    end
    before(:all) { benchmark_caption }
    before do
      # data bag secret
      Chef::Config[:encrypted_data_bag_secret] =
        File.join(File.dirname(__FILE__), '../data/encrypted_data_bag_secret')
      @data_bag_secret = Chef::EncryptedDataBagItem.load_secret

      # disable client and node search
      Chef::Config[:encrypted_attributes][:client_search] = []
      Chef::Config[:encrypted_attributes][:node_search] = []

      # Some data to encrypt
      @clear_hs = Mash.new(
        complex: 'object',
        more_complexity: [1, 'hated string'],
        raving: { 'more random stuff' => [3.0, true, false, nil] }
      )
      @data_bag_item = {
        'id' => 'data_bag_id', # required for data bags
        'data' => @clear_hs
      }

      # Create a data bag example
      data_bag = Chef::DataBag.new
      data_bag.name('encrypted')
      data_bag.save
      enc_hs =
        Chef::EncryptedDataBagItem.encrypt_data_bag_item(
          @data_bag_item, @data_bag_secret
        )
      @enc_data_bag_item = Chef::DataBagItem.from_hash(enc_hs)
      @enc_data_bag_item.data_bag('encrypted')
      @enc_data_bag_item.save

      # Create an encrypted attribute example
      @enc_attr = Chef::EncryptedAttribute.create(@clear_hs)
      node.set['encrypted']['attribute'] = @enc_attr
      node.save
    end

    benchmark_each_version 'Local EncryptedAttribute read' do
      Chef::EncryptedAttribute.load(@enc_attr)
    end

    benchmark_it 'Local EncryptedDataBag read' do
      data_bag_secret = Chef::EncryptedDataBagItem.load_secret
      data_bag_item =
        Chef::EncryptedDataBagItem.new(@enc_data_bag_item, data_bag_secret)
      data_bag_item['data']
    end

    benchmark_each_version 'Remote EncryptedAttribute read' do
      Chef::EncryptedAttribute.load_from_node(
        node.name, %w(encrypted attribute)
      )
    end

    benchmark_it 'Remote EncryptedDataBag read' do
      data_bag_item =
        Chef::EncryptedDataBagItem.load('encrypted', 'data_bag_id')
      data_bag_item['data']
    end

    benchmark_each_version 'Local EncryptedAttribute write' do
      Chef::EncryptedAttribute.create(@clear_hs)
    end

    benchmark_it 'Local EncryptedDataBag write' do
      data_bag_secret = Chef::EncryptedDataBagItem.load_secret
      enc_hs =
        Chef::EncryptedDataBagItem.encrypt_data_bag_item(
          @data_bag_item, data_bag_secret
        )
      enc_data_bag_item = Chef::DataBagItem.from_hash(enc_hs)
      enc_data_bag_item.data_bag('encrypted')
    end

    benchmark_each_version 'Remote EncryptedAttribute write' do
      enc_attr = Chef::EncryptedAttribute.create(@clear_hs)
      node.set['encrypted']['attribute'] = enc_attr
      node.save
    end

    benchmark_it 'Remote EncryptedDataBag write' do
      data_bag_secret = Chef::EncryptedDataBagItem.load_secret
      enc_hs =
        Chef::EncryptedDataBagItem.encrypt_data_bag_item(
          @data_bag_item, data_bag_secret
        )
      enc_data_bag_item = Chef::DataBagItem.from_hash(enc_hs)
      enc_data_bag_item.data_bag('encrypted')
      enc_data_bag_item.save
      node.save
    end

    benchmark_each_version 'Local EncryptedAttribute read/write' do
      enc_attr = Chef::EncryptedAttribute.create(@clear_hs)
      Chef::EncryptedAttribute.update(enc_attr)
      Chef::EncryptedAttribute.load(enc_attr)
    end

    benchmark_it 'Local EncryptedDataBag read/write' do
      data_bag_secret = Chef::EncryptedDataBagItem.load_secret
      enc_hs =
        Chef::EncryptedDataBagItem.encrypt_data_bag_item(
          @data_bag_item, data_bag_secret
        )
      enc_data_bag_item = Chef::DataBagItem.from_hash(enc_hs)
      enc_data_bag_item.data_bag('encrypted')
      enc_data_bag_item =
        Chef::EncryptedDataBagItem.load('encrypted', 'data_bag_id')
      enc_data_bag_item['data']
    end

    benchmark_each_version 'Remote EncryptedAttribute read/write' do
      enc_attr = Chef::EncryptedAttribute.create(@clear_hs)
      node.set['encrypted']['attribute'] = enc_attr
      node.save
      Chef::EncryptedAttribute.load_from_node(
        node.name, %w(encrypted attribute)
      )
    end

    benchmark_it 'Remote EncryptedDataBag read/write' do
      data_bag_secret = Chef::EncryptedDataBagItem.load_secret
      enc_hs =
        Chef::EncryptedDataBagItem.encrypt_data_bag_item(
          @data_bag_item, data_bag_secret
        )
      enc_data_bag_item = Chef::DataBagItem.from_hash(enc_hs)
      enc_data_bag_item.data_bag('encrypted')
      enc_data_bag_item.save
      node.save
      enc_data_bag_item =
        Chef::EncryptedDataBagItem.load('encrypted', 'data_bag_id')
      enc_data_bag_item['data']
    end

  end # when_the_chef_server is ready to rock!
end
