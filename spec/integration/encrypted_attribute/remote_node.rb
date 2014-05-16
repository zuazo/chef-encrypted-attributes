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

describe Chef::EncryptedAttribute::RemoteUsers do
  extend ChefZero::RSpec
  before(:all) do
    Chef::EncryptedAttribute::RemoteUsers.cache.clear
  end

  when_the_chef_server 'is ready to rock!' do
    before do
      @node_name = Chef::Config[:node_name]
      @remote_node = Chef::EncryptedAttribute::RemoteNode.new(@node_name)
      @attr1 = [ 'any-attribute-value', 0 , {} ]
      @attr2 = 'value2'
      @node = Chef::Node.new
      @node.name(@node_name)
      @node.set['attr1'] = @attr1
      @node.set['sub-attr']['attr2'] = @attr2
      @node.save
    end
    after do
      @node.destroy
    end

    context '#name' do

      it 'should return the node name' do
        @remote_node.name.should eql(@node_name)
      end

      it 'should be able to set the node name' do
        new_name = 'alice'
        @remote_node.name(new_name)
        @remote_node.name.should eql(new_name)
      end

    end # context #name

    context '#load_attribute' do

      it 'should read an existing node attribute' do
        @remote_node.load_attribute([ 'attr1' ]).should eql(@attr1)
        @remote_node.load_attribute([ 'sub-attr', 'attr2' ]).should eql(@attr2)
      end

      it 'should return nil if the attribute is not found' do
        @remote_node.load_attribute([ 'non-existing', 'attr' ]).should eql(nil)
      end

      it 'should raise an error if the attribute list is incorrect' do
        lambda { @remote_node.load_attribute('incorrect-attr-ary') }.should raise_error(ArgumentError)
      end

    end # context #load_attribute

    context '#save_attribute' do

      it 'should save the attribute' do
        @remote_node.save_attribute([ 'saved-attr', 'subattr2' ], 'A precious value')
        Chef::EncryptedAttribute::RemoteUsers.cache.clear
        @remote_node.load_attribute([ 'saved-attr', 'subattr2' ]).should eql('A precious value')
      end

      it 'should save attributes in the cache' do
        Chef::EncryptedAttribute::RemoteUsers.cache.max_size(20)
        Chef::EncryptedAttribute::RemoteUsers.cache.clear
        @remote_node.save_attribute([ 'saved-attr', 'subattr2' ], 'A precious value')
        @remote_node.load_attribute([ 'saved-attr', 'subattr2' ]).should eql('A precious value') # cached
      end

      it 'should raise an error if the attribute list is incorrect' do
        lambda { @remote_node.save_attribute('incorrect-attr-ary', 'some value') }.should raise_error(ArgumentError)
      end

    end # context #save_attribute

    context '#delete_attribute' do

      it 'should delete a node attribute' do
        node = Chef::Node.load(@node_name)
        node['sub-attr']['attr2'].should_not eql(nil)

        @remote_node.delete_attribute([ 'sub-attr', 'attr2']).should eql(true)

        node = Chef::Node.load(@node_name)
        node['sub-attr']['attr2'].should eql(nil)
      end

      it 'should ignore if the attribute does not exist' do
        @node['non-existent-attr'].should eql(nil)
        @remote_node.delete_attribute(['non-existent-attr']).should eql(false)
      end

      it 'should raise an error if the attribute list is incorrect' do
        lambda { @remote_node.delete_attribute('incorrect-attr-ary') }.should raise_error(ArgumentError)
      end

    end #context #delete_attribute

  end # when_the_chef_server is ready to rock!
end