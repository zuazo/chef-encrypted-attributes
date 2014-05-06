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
require 'chef/knife/encrypted_attribute_create'

describe Chef::Knife::EncryptedAttributeCreate do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::Config[:encrypted_attributes] = Mash.new
      Chef::EncryptedAttribute::RemoteClients.cache.clear
      Chef::EncryptedAttribute::RemoteUsers.cache.clear
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)

      Chef::Knife::EncryptedAttributeCreate.load_deps

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
      @node_client.public_key(@node_client.save['public_key'])
    end
    after do
      @admin.destroy
      @node.destroy
    end

    it 'should not be able to read the encrypted attribute by default' do
      knife = Chef::Knife::EncryptedAttributeCreate.new([ 'node1', 'encrypted.attribute' ])
      knife.should_receive(:edit_data).with(nil, nil).and_return('5')
      knife.run
      lambda { Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ]) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
    end

    it 'should be able to read the encrypted attribute if allowed' do
      knife = Chef::Knife::EncryptedAttributeCreate.new(['node1', 'encrypted.attribute', '--client-search', 'admin:true'])
      knife.should_receive(:edit_data).with(nil, nil).and_return('5')
      knife.run
      Chef::EncryptedAttribute.load_from_node('node1', [ 'encrypted', 'attribute' ]).should eql('5')
    end

    it 'should print error message when the attribute exists' do
      Chef::EncryptedAttribute.create_on_node('node1', [ 'existent' ], 'random-data')
      knife = Chef::Knife::EncryptedAttributeCreate.new([ 'node1', 'existent' ])
      knife.ui.should_receive(:fatal).with('Encrypted attribute already exists')
      lambda { knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeCreate.new([])
      knife.should_receive(:show_usage)
      knife.ui.should_receive(:fatal)
      lambda { knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeCreate.new([ 'node1' ])
      knife.should_receive(:show_usage)
      knife.ui.should_receive(:fatal)
      lambda { knife.run }.should raise_error(SystemExit)
    end

  end
end
