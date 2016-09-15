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

require 'integration_helper'
require 'chef/knife/encrypted_attribute_create'

describe Chef::Knife::EncryptedAttributeCreate do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:knife][:encrypted_attributes] = Mash.new
      clear_all_caches
      cache_size(:node, 0)

      Chef::Knife::EncryptedAttributeCreate.load_deps

      @admin_client = chef_create_admin_client(Chef::Config[:node_name])
      private_key = create_ssl_key(@admin_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)

      @admin_user = chef_create_admin_user('admin_user')
      @node, @node_client = chef_create_node('node1')
    end
    after do
      @admin_client.destroy
      @admin_user.destroy
      @node_client.destroy
      @node.destroy
    end

    it 'the written node is able to read the encrypted key' do
      knife =
        Chef::Knife::EncryptedAttributeCreate.new(%w(node1 encrypted.attribute))
      expect(knife).to receive(:edit_data).with(nil, nil).and_return('5')
      knife.run

      node_private_key = create_ssl_key(@node_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(node_private_key)
      expect(
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      ).to eql('5')
    end

    it 'the client is not able to read the encrypted attribute by default' do
      knife =
        Chef::Knife::EncryptedAttributeCreate.new(%w(node1 encrypted.attribute))
      expect(knife).to receive(:edit_data).with(nil, nil).and_return('5')
      knife.run

      private_key = create_ssl_key(@admin_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)
      expect do
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      end.to raise_error(
        Chef::EncryptedAttribute::DecryptionFailure,
        /Attribute data cannot be decrypted by the provided key\./
      )
    end

    it 'the client is able to read the encrypted attribute if allowed' do
      knife =
        Chef::Knife::EncryptedAttributeCreate.new(
          %w(node1 encrypted.attribute --client-search admin:true)
        )
      expect(knife).to receive(:edit_data).with(nil, nil).and_return('5')
      knife.run

      private_key = create_ssl_key(@admin_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)
      expect(
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      ).to eql('5')
    end

    it 'the user is not able to read the encrypted attribute by default' do
      knife =
        Chef::Knife::EncryptedAttributeCreate.new(%w(node1 encrypted.attribute))
      expect(knife).to receive(:edit_data).with(nil, nil).and_return('5')
      knife.run

      private_key = create_ssl_key(@admin_user.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)
      expect do
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      end.to raise_error(
        Chef::EncryptedAttribute::DecryptionFailure,
        /Attribute data cannot be decrypted by the provided key\./
      )
    end

    it 'the user is able to read the encrypted attribute if allowed' do
      knife =
        Chef::Knife::EncryptedAttributeCreate.new(
          [
            'node1', 'encrypted.attribute', '--encrypted-attribute-user',
            @admin_user.name
          ]
        )
      expect(knife).to receive(:edit_data).with(nil, nil).and_return('5')
      knife.run

      private_key = create_ssl_key(@admin_user.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)
      expect(
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      ).to eql('5')
    end

    it 'prints error message when the attribute exists' do
      Chef::EncryptedAttribute.create_on_node(
        'node1', %w(existent), 'random-data'
      )
      knife = Chef::Knife::EncryptedAttributeCreate.new(%w(node1 existent))
      expect(knife.ui).to receive(:fatal).with(
        'Encrypted attribute already exists'
      )
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeCreate.new([])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeCreate.new(%w(node1))
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end
  end
end
