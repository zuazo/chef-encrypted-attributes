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
require 'chef/knife/encrypted_attribute_update'

describe Chef::Knife::EncryptedAttributeUpdate do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:encrypted_attributes] = Mash.new
      Chef::EncryptedAttribute::RemoteClients.cache.clear
      Chef::EncryptedAttribute::RemoteUsers.cache.clear
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)

      Chef::Knife::EncryptedAttributeUpdate.load_deps

      @admin = Chef::ApiClient.new
      @admin.name(Chef::Config[:node_name])
      @admin.admin(true)
      admin_hs = @admin.save
      @admin.public_key(admin_hs['public_key'])
      @admin.private_key(admin_hs['private_key'])
      private_key = OpenSSL::PKey::RSA.new(@admin.private_key)
      Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(private_key)

      @node = Chef::Node.new
      @node.name('node1')
      @node.save
      @node_client = Chef::ApiClient.new
      @node_client.name('node1')
      @node_client.admin(false)
      node_hs = @node_client.save
      @node_client.public_key(node_hs['public_key'])
      @node_client.private_key(node_hs['private_key'])

      Chef::EncryptedAttribute.create_on_node('node1', [ 'encrypted', 'attribute' ], 'random-data')

      @stdout = StringIO.new
      Chef::Knife::UI.any_instance.stub(:stdout).and_return(@stdout)
    end
    after do
      @admin.destroy
      @node.destroy
      @node_client.destroy
    end

    it 'the client should not be able to read the encrypted attribute by default' do
      enc_attr = Chef::EncryptedAttribute.new
      enc_attr.create_on_node('node1', [ 'encrypted', 'attribute' ], 'random-data')
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'encrypted.attribute' ])
      lambda { knife.run }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key/)
    end

    it 'should not update the encrypted attribute if the privileges are the same' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:true' ])
      knife.run
      @stdout.rewind
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:true' ])
      knife.run
      @stdout.string.should match(/Encrypted attribute does not need updating\./)
    end

    it 'should update the encrypted attribute if the privileges has changed' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:true' ])
      knife.run
      @stdout.rewind
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'encrypted.attribute', '--client-search', 'admin:false' ])
      knife.run
      @stdout.string.should match(/Encrypted attribute updated\./)
    end

    it 'should print error message when the attribute does not exists' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1', 'non.existent' ])
      knife.ui.should_receive(:fatal).with('Encrypted attribute not found')
      lambda { knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([])
      knife.should_receive(:show_usage)
      knife.ui.should_receive(:fatal)
      lambda { knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([ 'node1' ])
      knife.should_receive(:show_usage)
      knife.ui.should_receive(:fatal)
      lambda { knife.run }.should raise_error(SystemExit)
    end

  end
end
