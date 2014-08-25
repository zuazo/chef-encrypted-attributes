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

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:knife][:encrypted_attributes] = Mash.new
      Chef::EncryptedAttribute::RemoteClients.cache.clear
      Chef::EncryptedAttribute::RemoteNodes.cache.clear
      Chef::EncryptedAttribute::RemoteUsers.cache.clear
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)

      Chef::Knife::EncryptedAttributeDelete.load_deps

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
      @node_client.public_key(@node_client.save['public_key'])
      @enc_attr_content = '5'
      Chef::EncryptedAttribute.create_on_node('node1', [ 'encrypted', 'attribute' ], @enc_attr_content)
      allow_any_instance_of(Chef::Knife::EncryptedAttributeEdit).to receive(:edit_data).with(@enc_attr_content, nil).and_return(@enc_attr_content)
    end
    after do
      @admin.destroy
      @node.destroy
      @node_client.destroy
    end

    it 'should not be able to delete the encrypted attribute if not allowed' do
      knife_edit = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:false' ])
      knife_edit.run

      knife_delete = Chef::Knife::EncryptedAttributeDelete.new([ 'node1', 'encrypted.attribute' ])
      expect { knife_delete.run }.to raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
    end

    it 'should be able to delete the encrypted attribute if not allowed but forced' do
      knife_edit = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:false' ])
      knife_edit.run

      knife_delete = Chef::Knife::EncryptedAttributeDelete.new([ 'node1', 'encrypted.attribute', '--force' ])
      expect(knife_delete.ui).to receive(:info).with('Encrypted attribute deleted.')
      expect { knife_delete.run }.not_to raise_error
      expect(Chef::EncryptedAttribute.exist_on_node?('node1', [ 'encrypted', 'attribute' ])).to eql(false)
    end

    it 'should be able to delete the encrypted attribute if allowed' do
      knife_edit = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:true' ])
      knife_edit.run
      expect(Chef::EncryptedAttribute.exist_on_node?('node1', [ 'encrypted', 'attribute' ])).to eql(true)

      knife_delete = Chef::Knife::EncryptedAttributeDelete.new([ 'node1', 'encrypted.attribute' ])
      expect(knife_delete.ui).to receive(:info).with('Encrypted attribute deleted.')
      knife_delete.run
      expect(Chef::EncryptedAttribute.exist_on_node?('node1', [ 'encrypted', 'attribute' ])).to eql(false)
    end

    it 'should do nothing when the encrypted attribute does not exist' do
      expect(Chef::EncryptedAttribute.exist_on_node?('node1', [ 'non', 'existent', 'attribute' ])).to eql(false)
      knife = Chef::Knife::EncryptedAttributeDelete.new([ 'node1', 'non.existent.attribute' ])
      expect(knife.ui).not_to receive(:info).with('Encrypted attribute deleted.')
      expect(Chef::EncryptedAttribute.exist_on_node?('node1', [ 'non', 'existent', 'attribute' ])).to eql(false)
      knife.run
    end

    it 'should print usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeDelete.new([])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'should print usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeDelete.new([ 'node1' ])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

  end
end
