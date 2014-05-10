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

describe Chef::EncryptedAttribute::RemoteNode do
  before do
    Chef::EncryptedAttribute::RemoteNode.cache.clear
    @RemoteNode = Chef::EncryptedAttribute::RemoteNode
    @RemoteNode.any_instance.stub(:search)
  end

  it 'should create a remote node without errors' do
    lambda { @RemoteNode.new('bob') }.should_not raise_error
  end

  it 'should include EncryptedAttribute::SearchHelper methods' do
    @RemoteNode.new('bob').should be_kind_of(Chef::EncryptedAttribute::SearchHelper)
  end

  describe '#name' do

    it 'should return the node name' do
      @RemoteNode.new('bob').name.should eql('bob')
    end

    it 'should be able to set the node name' do
      remote_node = @RemoteNode.new('bob')
      remote_node.name('alice')
      remote_node.name.should eql('alice')
    end

    it 'should raise an error if the name is not valid' do
      lambda { @RemoteNode.new({}) }.should raise_error(ArgumentError)
    end

  end

  describe '#load_attribute' do

    it 'should read the node attribute using SearchHelper' do
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1,
        true
      ).and_return(
        [ { 'value' => 'value1' } ]
      )
      remote_node.load_attribute(attr_ary).should eql('value1')
    end

    it 'should not cache the attribute if read multiple times and cache is disabled' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).twice.with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1,
        true
      ).and_return(
        [ { 'value' => 'value1' } ]
      )
      remote_node.load_attribute(attr_ary).should eql('value1')
      remote_node.load_attribute(attr_ary).should eql('value1')
    end

    it 'should cache the attribute if read multiple times and cache is enabled' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(10)
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).once.with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1,
        true
      ).and_return(
        [ { 'value' => 'value1' } ]
      )
      remote_node.load_attribute(attr_ary).should eql('value1')
      remote_node.load_attribute(attr_ary).should eql('value1') # cached
    end

    it 'should return nil if the attribute is not found' do
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1,
        true
      ).and_return(
        [ { 'value' => nil } ]
      )
      remote_node.load_attribute(attr_ary).should eql(nil)
    end

    it 'should return nil if the search result is wrong' do
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1,
        true
      ).and_return(
        [ { 'bad-value' => 'wrong' } ]
      )
      remote_node.load_attribute(attr_ary).should eql(nil)
    end


    it 'should raise an error if the attribute list is incorrect' do
      remote_node = @RemoteNode.new('bob')
      remote_node.should_not_receive(:search)
      lambda { remote_node.load_attribute('incorrect-attr-ary') }.should raise_error(ArgumentError)
    end

  end

  context '#save_attribute' do
    before do
      @node = Chef::Node.new
      @node.name('node1')
      @remote_node = Chef::EncryptedAttribute::RemoteNode.new('node1')
      Chef::Node.stub(:load).with('node1').and_return(@node)
    end

    it 'should save the node attribute' do
      @node.should_receive(:save).once
      Chef::Node.should_receive(:load).with('node1').once.and_return(@node)
      @remote_node.save_attribute([ 'attr1', 'subattr1' ], 'value1')
      @node['attr1']['subattr1'].should eql('value1')
    end

    it 'should cache the saved attribute' do
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(10)
      @node.should_receive(:save).once
      @remote_node.save_attribute([ 'attr1', 'subattr1' ], 'value1')

      @remote_node2 = Chef::EncryptedAttribute::RemoteNode.new('node1')
      @remote_node2.should_not_receive(:search)
      @remote_node2.load_attribute([ 'attr1', 'subattr1' ]).should eql('value1') # cached
    end

    it 'should raise an error if the attribute list is incorrect' do
      @node.should_not_receive(:save)
      lambda { @remote_node.save_attribute('incorrect-attr-ary', 'value1') }.should raise_error(ArgumentError)
    end

  end # context #save_attribute

  context '#delete_attribute' do
    before do
      @node = Chef::Node.new
      @node.name('node1')
      @node.normal['attr1']['subattr1'] = 'value1'
      @remote_node = Chef::EncryptedAttribute::RemoteNode.new('node1')
      Chef::Node.stub(:load).with('node1').and_return(@node)
    end

    it 'should delete a node attribute' do
      @node.should_receive(:save).once
      @remote_node.delete_attribute([ 'attr1', 'subattr1' ]).should eql(true)
    end

    it 'should not delete a non existent attribute' do
      @node.should_not_receive(:save)
      @remote_node.delete_attribute([ 'non-existent' ]).should eql(false)
    end

    it 'should raise an error if the attribute list is incorrect' do
      @node.should_not_receive(:save)
      lambda { @remote_node.delete_attribute('incorrect-attr-ary') }.should raise_error(ArgumentError)
    end

  end # context #delete_attribute

end
