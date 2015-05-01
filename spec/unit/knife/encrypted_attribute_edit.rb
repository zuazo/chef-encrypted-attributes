# encoding: UTF-8
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
    @knife =
      Chef::Knife::EncryptedAttributeEdit.new(%w(node1 encrypted.attribute))

    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
  end

  context '#edit_data' do
    before do
      allow(Chef::EncryptedAttribute)
        .to receive(:exist_on_node?).and_return(true)
      allow_any_instance_of(Chef::EncryptedAttribute)
        .to receive(:load_from_node).and_return({})
      allow_any_instance_of(Chef::EncryptedAttribute)
        .to receive(:create_on_node)
      allow_any_instance_of(Chef::Knife::EncryptedAttributeEdit)
        .to receive(:system).and_return(true)
      allow_any_instance_of(Chef::Knife::EncryptedAttributeEdit)
        .to receive(:sleep)
    end

    it 'edits data in plain text' do
      knife =
        Chef::Knife::EncryptedAttributeEdit.new(%w(node1 encrypted.attribute))
      expect(IO).to receive(:read).and_return('Attribute content')
      expect_any_instance_of(Chef::EncryptedAttribute)
        .to receive(:create_on_node)
        .with('node1', %w(encrypted attribute), 'Attribute content')
      knife.run
    end

    it 'edits data in JSON' do
      knife =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --input-format json)
        )
      expect(IO).to receive(:read).and_return('{ "attribute": "in_json" }')
      expect_any_instance_of(Chef::EncryptedAttribute)
        .to receive(:create_on_node)
        .with('node1', %w(encrypted attribute), 'attribute' => 'in_json')
      knife.run
    end

    it 'accepts JSON in quirk mode' do
      knife =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --input-format json)
        )
      expect(IO).to receive(:read).and_return('true')
      expect_any_instance_of(Chef::EncryptedAttribute)
        .to receive(:create_on_node)
        .with('node1', %w(encrypted attribute), true)
      knife.run
    end

    it 'throws an error for invalid JSON' do
      knife =
        Chef::Knife::EncryptedAttributeEdit.new(
          %w(node1 encrypted.attribute --input-format json)
        )
      expect(IO).to receive(:read).and_return('Bad-json')
      expect_any_instance_of(Chef::EncryptedAttribute)
        .not_to receive(:create_on_node)
      expect { knife.run }.to raise_error(YAJL_NAMESPACE::ParseError)
    end

    it 'throws an error if the editor fails' do
      allow_any_instance_of(Chef::Knife::EncryptedAttributeEdit)
        .to receive(:system).and_return(false)
      knife = Chef::Knife::EncryptedAttributeEdit.new(
        %w(node1 encrypted.attribute)
      )
      expect { knife.run }
        .to raise_error(RuntimeError, 'Please set EDITOR environment variable')
    end
  end # context #edit_data
end
