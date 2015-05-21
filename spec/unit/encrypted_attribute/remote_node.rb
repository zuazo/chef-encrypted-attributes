# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014-2015 Onddo Labs, SL. (www.onddo.com)
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

describe Chef::EncryptedAttribute::RemoteNode do
  let(:remote_node_class) { Chef::EncryptedAttribute::RemoteNode }
  before do
    clear_cache(:node)
    allow_any_instance_of(remote_node_class).to receive(:search_by_name)
  end

  it 'creates a remote node without errors' do
    expect { remote_node_class.new('bob') }.not_to raise_error
  end

  it 'includes EncryptedAttribute::SearchHelper methods' do
    expect(remote_node_class.new('bob'))
      .to be_kind_of(Chef::EncryptedAttribute::SearchHelper)
  end

  describe '#name' do
    it 'returns the node name' do
      expect(remote_node_class.new('bob').name).to eql('bob')
    end

    it 'is able to set the node name' do
      remote_node = remote_node_class.new('bob')
      remote_node.name('alice')
      expect(remote_node.name).to eql('alice')
    end

    it 'throws an error if the name is not valid' do
      expect { remote_node_class.new({}) }.to raise_error(ArgumentError)
    end
  end

  describe '#load_attribute' do
    it 'reads the node attribute using SearchHelper' do
      attr_ary = %w(attr1 subattr1)
      remote_node = remote_node_class.new('bob')
      expect(remote_node).to receive(:search_by_name).with(
        :node,
        remote_node.name,
        { 'value' => attr_ary },
        1000,
        true
      ).and_return(
        [{ 'value' => 'value1' }]
      )
      expect(remote_node.load_attribute(attr_ary)).to eql('value1')
    end

    it 'does not cache the attribute if read multiple times and cache is '\
       'disabled' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)
      attr_ary = %w(attr1 subattr1)
      remote_node = remote_node_class.new('bob')
      expect(remote_node).to receive(:search_by_name).twice.with(
        :node,
        remote_node.name,
        { 'value' => attr_ary },
        1000,
        true
      ).and_return(
        [{ 'value' => 'value1' }]
      )
      expect(remote_node.load_attribute(attr_ary)).to eql('value1')
      expect(remote_node.load_attribute(attr_ary)).to eql('value1')
    end

    it 'caches the attribute if read multiple times and cache is enabled' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(10)
      attr_ary = %w(attr1 subattr1)
      remote_node = remote_node_class.new('bob')
      expect(remote_node).to receive(:search_by_name).once.with(
        :node,
        remote_node.name,
        { 'value' => attr_ary },
        1000,
        true
      ).and_return(
        [{ 'value' => 'value1' }]
      )
      expect(remote_node.load_attribute(attr_ary)).to eql('value1')
      expect(remote_node.load_attribute(attr_ary)).to eql('value1') # cached
    end

    it 'returns nil if the attribute is not found' do
      attr_ary = %w(attr1 subattr1)
      remote_node = remote_node_class.new('bob')
      expect(remote_node).to receive(:search_by_name).with(
        :node,
        remote_node.name,
        { 'value' => attr_ary },
        1000,
        true
      ).and_return(
        [{ 'value' => nil }]
      )
      expect(remote_node.load_attribute(attr_ary)).to eql(nil)
    end

    it 'returns nil if the search result is wrong' do
      attr_ary = %w(attr1 subattr1)
      remote_node = remote_node_class.new('bob')
      expect(remote_node).to receive(:search_by_name).with(
        :node,
        remote_node.name,
        { 'value' => attr_ary },
        1000,
        true
      ).and_return(
        [{ 'bad-value' => 'wrong' }]
      )
      expect(remote_node.load_attribute(attr_ary)).to eql(nil)
    end

    it 'throws an error if the attribute list is incorrect' do
      remote_node = remote_node_class.new('bob')
      expect(remote_node).not_to receive(:search_by_name)
      expect { remote_node.load_attribute('incorrect-attr-ary') }
        .to raise_error(ArgumentError)
    end
  end

  context '#save_attribute' do
    let(:node) do
      node = Chef::Node.new
      node.name('node1')
      node
    end
    let(:remote_node) { Chef::EncryptedAttribute::RemoteNode.new(node.name) }
    before do
      allow(Chef::Node).to receive(:load).with(node.name).and_return(node)
    end

    it 'saves the node attribute' do
      expect(node).to receive(:save).once
      expect(Chef::Node).to receive(:load).with('node1').once.and_return(node)
      remote_node.save_attribute(%w(attr1 subattr1), 'value1')
      expect(node['attr1']['subattr1']).to eql('value1')
    end

    it 'caches the saved attribute' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(10)
      expect(node).to receive(:save).once
      remote_node.save_attribute(%w(attr1 subattr1), 'value1')

      remote_node2 = Chef::EncryptedAttribute::RemoteNode.new('node1')
      expect(remote_node2).not_to receive(:search_by_name)
      # cached:
      expect(remote_node2.load_attribute(%w(attr1 subattr1))).to eql('value1')
    end

    it 'raises an error if the attribute list is incorrect' do
      expect(node).not_to receive(:save)
      expect { remote_node.save_attribute('incorrect-attr-ary', 'value1') }
        .to raise_error(ArgumentError)
    end
  end # context #save_attribute

  context '#delete_attribute' do
    let(:node) do
      node = Chef::Node.new
      node.name('node1')
      node.normal['attr1']['subattr1'] = 'value1'
      node
    end
    let(:remote_node) { Chef::EncryptedAttribute::RemoteNode.new(node.name) }
    before do
      allow(Chef::Node).to receive(:load).with(node.name).and_return(node)
    end

    it 'deletes a node attribute' do
      expect(node).to receive(:save).once
      expect(remote_node.delete_attribute(%w(attr1 subattr1))).to eql(true)
    end

    it 'does not delete a non existent attribute' do
      expect(node).not_to receive(:save)
      expect(remote_node.delete_attribute(%w(non-existent))).to eql(false)
    end

    it 'throws an error if the attribute list is incorrect' do
      expect(node).not_to receive(:save)
      expect { remote_node.delete_attribute('incorrect-attr-ary') }
        .to raise_error(ArgumentError)
    end
  end # context #delete_attribute
end
