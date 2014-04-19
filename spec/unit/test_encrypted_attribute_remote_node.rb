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

  describe '#load' do

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
        [ { 'value' => nil } ]
      )
      remote_node.load_attribute(attr_ary)
    end

    xit 'should return nil if the attribute is not found' do
      attr_ary = [ 'attr1', 'subattr1' ]
      remote_node = @RemoteNode.new('bob')
      remote_node.should_receive(:search).with(
        :node,
        "name:#{remote_node.name}",
        { 'value' => attr_ary },
        1
      ).and_return(
        [ { 'value' => [] } ]
      )
      remote_node.load_attribute(attr_ary).should eql(nil)
    end

    it 'should raise an error if the attribute list is incorrect' do
      remote_node = @RemoteNode.new('bob')
      remote_node.should_not_receive(:search)
      lambda { remote_node.load_attribute('incorrect-attr-ary') }.should raise_error(ArgumentError)
    end

  end

end
