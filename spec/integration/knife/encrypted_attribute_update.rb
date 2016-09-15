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
require 'chef/knife/encrypted_attribute_update'

describe Chef::Knife::EncryptedAttributeUpdate do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:log) { Chef::VERSION < '12' ? stdout : stderr }
    before do
      Chef::Config[:knife][:encrypted_attributes] = Mash.new
      clear_all_caches
      cache_size(:node, 0)

      Chef::Knife::EncryptedAttributeUpdate.load_deps

      @admin = chef_create_admin_client(Chef::Config[:node_name])
      private_key = create_ssl_key(@admin.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(private_key)

      @node1, @node1_client = chef_create_node('node1')
      @node2, @node2_client = chef_create_node('node2')

      Chef::EncryptedAttribute.create_on_node(
        'node1',
        %w(encrypted attribute),
        'random-data',
        client_search: 'admin:true', node_search: 'role:webapp'
      )

      allow_any_instance_of(Chef::Knife::UI).to receive(:stdout)
        .and_return(stdout)
      allow_any_instance_of(Chef::Knife::UI).to receive(:stderr)
        .and_return(stderr)
    end
    after do
      @admin.destroy
      @node1.destroy
      @node1_client.destroy
      @node2.destroy
      @node2_client.destroy
    end

    it 'the written node is able to read the encrypted key after update' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new(
        %w(node1 encrypted.attribute)
      )
      knife.run

      node_private_key = create_ssl_key(@node1_client.private_key)
      allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
        .to receive(:key).and_return(node_private_key)
      expect(
        Chef::EncryptedAttribute.load_from_node(
          'node1', %w(encrypted attribute)
        )
      ).to eql('random-data')
    end

    it 'the client is not able to update the encrypted attribute by default' do
      enc_attr = Chef::EncryptedAttribute.new
      enc_attr.create_on_node('node1', %w(encrypted attribute), 'random-data')
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(
        node1 encrypted.attribute
        --client-search *:*
      ))
      expect { knife.run }
        .to raise_error(
          Chef::EncryptedAttribute::DecryptionFailure,
          /Attribute data cannot be decrypted by the provided key/
        )
    end

    it 'does not update the encrypted attribute if the privileges are the '\
       'same' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(
        node1 encrypted.attribute
        --client-search admin:true
        --node-search role:webapp
      ))
      knife.run
      log.rewind
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(
        node1 encrypted.attribute
        --client-search admin:true
        --node-search role:webapp
      ))
      knife.run
      expect(log.string)
        .to match(/Encrypted attribute does not need updating\./)
    end

    it 'updates the encrypted attribute if the privileges has changed' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(
        node1 encrypted.attribute
        --client-search admin:true
        --node-search role:webapp
      ))
      knife.run
      log.rewind
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(
        node1 encrypted.attribute
        --client-search admin:false
        --node-search role:webapp
      ))
      knife.run
      expect(log.string).to match(/Encrypted attribute updated\./)
    end

    it 'prints error message when the attribute does not exists' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(node1 non.existent))
      expect(knife.ui).to receive(:fatal).with('Encrypted attribute not found')
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when a node name is not provided' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new([])
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end

    it 'prints usage and exit when an attribute is not provided' do
      knife = Chef::Knife::EncryptedAttributeUpdate.new(%w(node1))
      expect(knife).to receive(:show_usage)
      expect(knife.ui).to receive(:fatal)
      expect { knife.run }.to raise_error(SystemExit)
    end
  end
end
