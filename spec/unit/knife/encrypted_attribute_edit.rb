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
require 'chef/knife/encrypted_attribute_edit'

describe Chef::Knife::EncryptedAttributeEdit do

  before do
    Chef::Knife::EncryptedAttributeEdit.load_deps
    @knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute' ])

    @stdout = StringIO.new
    @knife.ui.stub(:stdout).and_return(@stdout)
  end

  context '#edit_data' do
    before do
      Chef::EncryptedAttribute.stub(:exists_on_node?).and_return(true)
      Chef::EncryptedAttribute.any_instance.stub(:load_from_node).and_return({})
      Chef::EncryptedAttribute.any_instance.stub(:create_on_node)
      Chef::Knife::EncryptedAttributeEdit.any_instance.stub(:system).and_return(true)
      Chef::Knife::EncryptedAttributeEdit.any_instance.stub(:sleep)
    end

    it 'should edit data in plain text' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute' ])
      IO.should_receive(:read).and_return('Attribute content')
      Chef::EncryptedAttribute.any_instance.should_receive(:create_on_node).with('node1', [ 'encrypted', 'attribute' ], 'Attribute content')
      knife.run
    end

    it 'should edit data in JSON' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--input-format', 'json' ])
      IO.should_receive(:read).and_return('{ "attribute": "in_json" }')
      Chef::EncryptedAttribute.any_instance.should_receive(:create_on_node).with('node1', [ 'encrypted', 'attribute' ], { 'attribute' => 'in_json' })
      knife.run
    end

    it 'should throw an error for invalid JSON' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--input-format', 'json' ])
      IO.should_receive(:read).and_return('Bad-json')
      Chef::EncryptedAttribute.any_instance.should_not_receive(:create_on_node)
      lambda { knife.run }.should raise_error(Yajl::ParseError)
    end

    it 'should print a message when the previous content was not in JSON' do
      knife = Chef::Knife::EncryptedAttributeEdit.new([ 'node1', 'encrypted.attribute', '--input-format', 'json' ])
      Chef::EncryptedAttribute.any_instance.stub(:load_from_node).and_return('non-json')
      IO.should_receive(:read).and_return('{ "attribute": "in_json" }')
      knife.ui.should_receive(:warn).with('Previous data is not in JSON, it will be overwritten.')
      knife.run
    end

  end # context #edit_data

end
