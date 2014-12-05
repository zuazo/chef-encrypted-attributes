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

describe Chef::Knife::EncryptedAttributeEdit do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:knife][:encrypted_attributes] = Mash.new
      Chef::EncryptedAttribute::RemoteClients.cache.clear
      Chef::EncryptedAttribute::RemoteNodes.cache.clear
      Chef::EncryptedAttribute::RemoteUsers.cache.clear
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)

      Chef::Knife::EncryptedAttributeEdit.load_deps

      @admin = Chef::ApiClient.new
      @admin.name(Chef::Config[:node_name])
      @admin.admin(true)
      admin_hs = @admin.save
      @admin.public_key(admin_hs['public_key'])
      @admin.private_key(admin_hs['private_key'])
      private_key = OpenSSL::PKey::RSA.new(@admin.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode).to receive(:key).and_return(private_key)

      @node = Chef::Node.new
      @node.name('node1')
      @node.save
      @node_client = Chef::ApiClient.new
      @node_client.name('node1')
      @node_client.admin(false)
      node_hs = @node_client.save
      @node_client.public_key(node_hs['public_key'])
      @node_client.private_key(node_hs['private_key'])

      @orig_content = '3'
      Chef::EncryptedAttribute.create_on_node('node1', [ 'encrypted', 'attribute' ], @orig_content)
    end
    after do
      @admin.destroy
      @node.destroy
    end

    it 'the written node is able to read the encrypted key' do
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute' ])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run

      node_private_key = OpenSSL::PKey::RSA.new(@node_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode).to receive(:key).and_return(node_private_key)
      expect(Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ])).to eql('5')
    end

    it 'is not able to read the encrypted attribute by default' do
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute' ])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run
      expect { Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ]) }.to raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
    end

    it 'is able to read the encrypted attribute if the client is allowed' do
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new(['node1', 'encrypted.attribute', '--client-search', 'admin:true'])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run
      expect(Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ])).to eql(new_content)
    end

    it 'is not able to read the encrypted attribute without using partial search' do
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new(['node1', 'encrypted.attribute', '--client-search', 'admin:true', '--disable-partial-search'])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run
      expect(Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ])).to eql(new_content)
    end

    it 'is able to read the encrypted attribute if the user is allowed' do
      user = Chef::User.new
      user.name('user1')
      user = user.create
      private_key = OpenSSL::PKey::RSA.new(user.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode).to receive(:key).and_return(private_key)

      Chef::EncryptedAttribute.create_on_node('node1', [ 'encrypted', 'attribute' ], @orig_content)
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new(['node1', 'encrypted.attribute', '--encrypted-attribute-user', 'user1'])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run
      expect(Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ])).to eql(new_content)

      user.destroy
    end

    it 'is able to use version 1 encrypted attribute' do
      new_content = '5'
      knife = Chef::Knife::EncryptedAttributeEdit.new(['node1', 'encrypted.attribute', '--client-search', 'admin:true', '--encrypted-attribute-version', '1'])
      expect(knife).to receive(:edit_data).with(@orig_content, nil).and_return(new_content)
      knife.run
      expect(Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ])).to eql(new_content)
    end

    it 'prints error message when the attribute does not exists' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'non.existent' ])
      expect(knife.ui).to receive(:fatal).with('Encrypted attribute not found')
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1' ])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

  end
end
