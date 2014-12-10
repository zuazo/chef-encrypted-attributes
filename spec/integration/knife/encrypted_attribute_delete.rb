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
require 'chef/knife/encrypted_attribute_edit'
require 'chef/knife/encrypted_attribute_delete'

describe Chef::Knife::EncryptedAttributeDelete do
  extend ChefZero::RSpec
  let(:enc_attr_content) { '5' }

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:knife][:encrypted_attributes] = Mash.new
      clear_all_caches
      cache_size(:node, 0)

      Chef::Knife::EncryptedAttributeDelete.load_deps

      @admin = chef_create_admin_client(Chef::Config[:node_name])
      private_key = create_ssl_key(@admin.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)

      @node, @node_client = chef_create_node('node1')

      Chef::EncryptedAttribute.create_on_node(
        'node1', %w(encrypted attribute), enc_attr_content
      )
      allow_any_instance_of(Chef::Knife::EncryptedAttributeEdit)
        .to receive(:edit_data).with(enc_attr_content, nil)
        .and_return(enc_attr_content)
    end
    after do
      @admin.destroy
      @node.destroy
      @node_client.destroy
    end

    it 'is not able to delete the encrypted attribute if not allowed' do
      knife_edit =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --client-search admin:false)
        )
      knife_edit.run

      knife_delete =
        Chef::Knife::EncryptedAttributeDelete.new(
          %w(node1 encrypted.attribute)
        )
      expect { knife_delete.run }
        .to raise_error(
          Chef::EncryptedAttribute::DecryptionFailure,
          /Attribute data cannot be decrypted by the provided key\./
        )
    end

    it 'is able to delete the encrypted attribute if not allowed but forced' do
      knife_edit =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --client-search admin:false)
        )
      knife_edit.run

      knife_delete =
        Chef::Knife::EncryptedAttributeDelete.new(
          %w(node1 encrypted.attribute --force)
        )
      expect(knife_delete.ui).to receive(:info)
        .with('Encrypted attribute deleted.')
      expect { knife_delete.run }.not_to raise_error
      expect(Chef::EncryptedAttribute.exist_on_node?(
        'node1', %w(encrypted attribute)
      )).to eql(false)
    end

    it 'is able to delete the encrypted attribute if allowed' do
      knife_edit =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --client-search admin:true)
        )
      knife_edit.run
      expect(Chef::EncryptedAttribute.exist_on_node?(
        'node1', %w(encrypted attribute)
      )).to eql(true)

      knife_delete =
        Chef::Knife::EncryptedAttributeDelete.new(%w(node1 encrypted.attribute))
      expect(knife_delete.ui).to receive(:info)
        .with('Encrypted attribute deleted.')
      knife_delete.run
      expect(Chef::EncryptedAttribute.exist_on_node?(
        'node1', %w(encrypted attribute)
      )).to eql(false)
    end

    it 'does nothing when the encrypted attribute does not exist' do
      expect(Chef::EncryptedAttribute.exist_on_node?(
        'node1', %w(non existent attribute)
      )).to eql(false)
      knife =
        Chef::Knife::EncryptedAttributeDelete.new(
          %w(node1 non.existent.attribute)
        )
      expect(knife.ui).not_to receive(:info)
        .with('Encrypted attribute deleted.')
      expect(Chef::EncryptedAttribute.exist_on_node?(
        'node1', %w(non existent attribute)
      )).to eql(false)
      knife.run
    end

    it 'prints usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeDelete.new([])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeDelete.new(%w(node1))
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

  end
end
