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

require 'spec_helper'

describe Chef::EncryptedAttribute do
  let(:encrypted_attribute_class) { Chef::EncryptedAttribute }
  let(:encrypted_mash_class) { Chef::EncryptedAttribute::EncryptedMash }
  let(:remote_node_class) { Chef::EncryptedAttribute::RemoteNode }
  let(:config_class) { Chef::EncryptedAttribute::Config }
  let(:client_key) { create_ssl_key }
  before(:all) { clear_all_caches }
  before do
    Chef::Config[:encrypted_attributes] = Mash.new

    allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
      .to receive(:key).and_return(client_key)
  end

  context '#self.create' do
    before do
      allow_any_instance_of(encrypted_attribute_class).to receive(:create)
    end

    it 'creates an EncryptedAttribute object' do
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class).to receive(:new).and_return(body)
      encrypted_attribute_class.create(%w(a))
    end

    it 'creates an EncryptedAttribute object with a custom config' do
      Chef::Config[:encrypted_attributes] = { partial_search: true }
      custom_config = config_class.new(partial_search: false)
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class)
        .to receive(:new).with(an_instance_of(config_class)).once
        .and_return(body)
      encrypted_attribute_class.create(%w(a), custom_config)
    end

    it 'calls EncryptedAttribute#create and returns its result' do
      expect_any_instance_of(encrypted_attribute_class)
        .to receive(:create).with(%w(a)).and_return('create')
      expect(encrypted_attribute_class.create(%w(a))).to eql('create')
    end
  end # context #self.create

  context '#self.create_on_node' do
    before do
      allow_any_instance_of(encrypted_attribute_class)
        .to receive(:create_on_node)
    end

    it 'creates an EncryptedAttribute object' do
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class).to receive(:new).and_return(body)
      encrypted_attribute_class.create_on_node('node1', %w(a), 'value')
    end

    it 'creates an EncryptedAttribute object with a custom config' do
      Chef::Config[:encrypted_attributes] = { partial_search: true }
      custom_config = config_class.new(partial_search: false)
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class)
        .to receive(:new).with(an_instance_of(config_class)).once
        .and_return(body)
      encrypted_attribute_class.create_on_node(
        'node1', %w(a), 'value', custom_config
      )
    end

    it 'calls EncryptedAttribute#create_on_node and returns its result' do
      expect_any_instance_of(encrypted_attribute_class)
        .to receive(:create_on_node).with('node1', %w(a), 'value')
        .and_return('create_on_node')
      expect(encrypted_attribute_class.create_on_node('node1', %w(a), 'value'))
        .to eql('create_on_node')
    end
  end # context #self.create_on_node

  %w(load update).each do |meth|
    context "#self.#{meth}" do
      before do
        allow_any_instance_of(encrypted_attribute_class).to receive(meth.to_sym)
      end

      it 'creates an EncryptedAttribute object' do
        body = encrypted_attribute_class.new
        expect(encrypted_attribute_class).to receive(:new).and_return(body)
        encrypted_attribute_class.send(meth, %w(a))
      end

      it 'creates an EncryptedAttribute object with a custom config' do
        Chef::Config[:encrypted_attributes] = { partial_search: true }
        custom_config = config_class.new(partial_search: false)
        body = encrypted_attribute_class.new
        expect(encrypted_attribute_class)
          .to receive(:new).with(an_instance_of(config_class)).once
          .and_return(body)
        encrypted_attribute_class.send(meth, %w(a), custom_config)
      end

      it "calls EncryptedAttribute##{meth} and returns its result" do
        expect_any_instance_of(encrypted_attribute_class)
          .to receive(meth.to_sym) .with(%w(a)).and_return(meth)
        expect(encrypted_attribute_class.send(meth, %w(a))).to eql(meth)
      end
    end # context #self.meth
  end # %w(load update).each do |meth|

  context '#self.load_from_node' do
    before do
      allow_any_instance_of(encrypted_attribute_class)
        .to receive(:load_from_node)
    end

    it 'creates an EncryptedAttribute object' do
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class).to receive(:new).and_return(body)
      encrypted_attribute_class.load_from_node('node1', %w(a))
    end

    it 'creates an EncryptedAttribute object with a custom config' do
      Chef::Config[:encrypted_attributes] = { partial_search: true }
      custom_config = config_class.new(partial_search: false)
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class)
        .to receive(:new).with(an_instance_of(config_class)).once
        .and_return(body)
      encrypted_attribute_class.load_from_node('node1', %w(a), custom_config)
    end

    it 'calls EncryptedAttribute#load_from_node and returns its result' do
      expect_any_instance_of(encrypted_attribute_class)
        .to receive(:load_from_node).with('node1', %w(a))
        .and_return('load_from_node')
      expect(encrypted_attribute_class.load_from_node('node1', %w(a)))
        .to eql('load_from_node')
    end
  end # context #load_from_node

  context '#self.update_on_node' do
    before do
      allow_any_instance_of(encrypted_attribute_class)
        .to receive(:update_on_node)
    end

    it 'updates an EncryptedAttribute object' do
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class).to receive(:new).and_return(body)
      encrypted_attribute_class.update_on_node('node1', %w(a))
    end

    it 'updates an EncryptedAttribute object with a custom config' do
      Chef::Config[:encrypted_attributes] = { partial_search: true }
      custom_config = config_class.new(partial_search: false)
      body = encrypted_attribute_class.new
      expect(encrypted_attribute_class)
        .to receive(:new).with(an_instance_of(config_class)).once
        .and_return(body)
      encrypted_attribute_class.update_on_node('node1', %w(a), custom_config)
    end

    it 'calls EncryptedAttribute#update_on_node and returns its result' do
      expect_any_instance_of(encrypted_attribute_class)
        .to receive(:update_on_node).with('node1', %w(a))
        .and_return('update_on_node')
      expect(encrypted_attribute_class.update_on_node('node1', %w(a)))
        .to eql('update_on_node')
    end
  end # context #update_on_node

  context '#self.exist?' do
    before { allow_any_instance_of(encrypted_mash_class).to receive(:exist?) }

    it 'does not create an EncryptedMash object' do
      expect(Chef::Log).to_not receive(:warn)
      expect(encrypted_mash_class).not_to receive(:new)
      encrypted_attribute_class.exist?(%w(a))
    end

    it 'calls EncryptedMash#exist? and returns its result' do
      expect(Chef::Log).to_not receive(:warn)
      expect(encrypted_mash_class)
        .to receive(:exist?).with(%w(a)).and_return(true)
      expect(encrypted_attribute_class.exist?(%w(a))).to eql(true)
      expect(encrypted_mash_class)
        .to receive(:exist?).with(%w(a)).and_return(false)
      expect(encrypted_attribute_class.exist?(%w(a))).to eql(false)
    end
  end # context #exist?

  context '#self.exists?' do
    before do
      allow_any_instance_of(encrypted_mash_class).to receive(:exist?)
    end

    it 'does not create an EncryptedMash object' do
      expect(Chef::Log).to receive(:warn).once.with(/is deprecated in favor of/)
      expect(encrypted_mash_class).not_to receive(:new)
      encrypted_attribute_class.exists?(%w(a))
    end

    it 'calls EncryptedMash#exist? and returns its result' do
      expect(Chef::Log)
        .to receive(:warn).twice.with(/is deprecated in favor of/)
      expect(encrypted_mash_class)
        .to receive(:exist?).with(%w(a)).and_return(true)
      expect(encrypted_attribute_class.exists?(%w(a))).to eql(true)
      expect(encrypted_mash_class)
        .to receive(:exist?).with(%w(a)).and_return(false)
      expect(encrypted_attribute_class.exists?(%w(a))).to eql(false)
    end
  end # context #exists?

  context '#self.exist_on_node?' do
    it 'loads the remote attribute and calls #exist?' do
      expect(Chef::Log).to_not receive(:warn)
      expect_any_instance_of(config_class)
        .to receive(:partial_search).and_return('partial_search')
      expect_any_instance_of(config_class)
        .to receive(:search_max_rows).and_return('rows')
      expect_any_instance_of(remote_node_class)
        .to receive(:load_attribute).with(%w(attr), 'rows', 'partial_search')
        .and_return('load_attribute')
      expect(encrypted_attribute_class)
        .to receive(:exist?).with('load_attribute').and_return('exist?')
      expect(encrypted_attribute_class.exist_on_node?('node1', %w(attr)))
        .to eql('exist?')
    end
  end # context #self.exist_on_node?

  context '#self.exists_on_node?' do
    it 'loads the remote attribute and calls #exist?' do
      expect(Chef::Log).to receive(:warn).once.with(/is deprecated in favor of/)
      expect_any_instance_of(config_class)
        .to receive(:partial_search).and_return('partial_search')
      expect_any_instance_of(config_class)
        .to receive(:search_max_rows).and_return('rows')
      expect_any_instance_of(remote_node_class)
        .to receive(:load_attribute).with(%w(attr), 'rows', 'partial_search')
        .and_return('load_attribute')
      expect(encrypted_attribute_class)
        .to receive(:exist?).with('load_attribute').and_return('exist?')
      expect(encrypted_attribute_class.exists_on_node?('node1', %w(attr)))
        .to eql('exist?')
    end
  end # context #self.exists_on_node?
end # describe Chef::EncryptedAttribute::Config
