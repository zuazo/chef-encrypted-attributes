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

describe Chef::EncryptedAttribute do
  before(:all) do
    Chef::EncryptedAttribute::RemoteClients.cache.clear
    Chef::EncryptedAttribute::RemoteUsers.cache.clear
  end
  before do
    Chef::Config[:encrypted_attributes] = Mash.new

    @client_key = OpenSSL::PKey::RSA.new(2048)
    allow_any_instance_of(Chef::EncryptedAttribute::LocalNode).to receive(:key).and_return(@client_key)

    @EncryptedAttribute = Chef::EncryptedAttribute
    @EncryptedMash = Chef::EncryptedAttribute::EncryptedMash
    @RemoteNode = Chef::EncryptedAttribute::RemoteNode
    @Config = Chef::EncryptedAttribute::Config
  end

  context '#self.create' do
    before do
      allow_any_instance_of(@EncryptedAttribute).to receive(:create)
    end

    it 'should create an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).and_return(body)
      @EncryptedAttribute.create([ 'a' ])
    end

    it 'should create an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.create([ 'a' ], custom_config)
    end

    it 'should call EncryptedAttribute#create and return its result' do
      expect_any_instance_of(@EncryptedAttribute).to receive(:create).with([ 'a' ]).and_return('create')
      expect(@EncryptedAttribute.create([ 'a' ])).to eql('create')
    end

  end # context #self.create

  context '#self.create_on_node' do
    before do
      allow_any_instance_of(@EncryptedAttribute).to receive(:create_on_node)
    end

    it 'should create an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).and_return(body)
      @EncryptedAttribute.create_on_node('node1', [ 'a' ], 'value')
    end

    it 'should create an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.create_on_node('node1', [ 'a' ], 'value', custom_config)
    end

    it 'should call EncryptedAttribute#create_on_node and return its result' do
      expect_any_instance_of(@EncryptedAttribute).to receive(:create_on_node).with('node1', [ 'a' ], 'value').and_return('create_on_node')
      expect(@EncryptedAttribute.create_on_node('node1', [ 'a' ], 'value')).to eql('create_on_node')
    end

  end # context #self.exists_on_node?

  %w{load update}.each do |meth|

    context "#self.#{meth}" do
      before do
        allow_any_instance_of(@EncryptedAttribute).to receive(meth.to_sym)
      end

      it 'should create an EncryptedAttribute object' do
        body = @EncryptedAttribute.new
        expect(@EncryptedAttribute).to receive(:new).and_return(body)
        @EncryptedAttribute.send(meth, [ 'a' ])
      end

      it 'should create an EncryptedAttribute object with a custom config' do
        orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
        custom_config = @Config.new({ :partial_search => false })
        body = @EncryptedAttribute.new
        expect(@EncryptedAttribute).to receive(:new).with(an_instance_of(@Config)).once.and_return(body)
        @EncryptedAttribute.send(meth, [ 'a' ], custom_config)
      end

      it "should call EncryptedAttribute##{meth} and return its result" do
        expect_any_instance_of(@EncryptedAttribute).to receive(meth.to_sym).with([ 'a' ]).and_return("#{meth}")
        expect(@EncryptedAttribute.send(meth, [ 'a' ])).to eql("#{meth}")
      end

    end # context #self.meth

  end # %w{load update}.each do |meth|

  context '#self.load_from_node' do
    before do
      allow_any_instance_of(@EncryptedAttribute).to receive(:load_from_node)
    end

    it 'should create an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ])
    end

    it 'should create an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ], custom_config)
    end

    it 'should call EncryptedAttribute#load_from_node and return its result' do
      expect_any_instance_of(@EncryptedAttribute).to receive(:load_from_node).with('node1', [ 'a' ]).and_return('load_from_node')
      expect(@EncryptedAttribute.load_from_node('node1', [ 'a' ])).to eql('load_from_node')
    end

  end # context #load_from_node

  context '#self.update_on_node' do
    before do
      allow_any_instance_of(@EncryptedAttribute).to receive(:update_on_node)
    end

    it 'should update an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).and_return(body)
      @EncryptedAttribute.update_on_node('node1', [ 'a' ])
    end

    it 'should update an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      expect(@EncryptedAttribute).to receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.update_on_node('node1', [ 'a' ], custom_config)
    end

    it 'should call EncryptedAttribute#update_on_node and return its result' do
      expect_any_instance_of(@EncryptedAttribute).to receive(:update_on_node).with('node1', [ 'a' ]).and_return('update_on_node')
      expect(@EncryptedAttribute.update_on_node('node1', [ 'a' ])).to eql('update_on_node')
    end

  end # context #update_on_node

  context '#self.exists?' do
    before do
      allow_any_instance_of(@EncryptedMash).to receive(:exists?)
    end

    it 'should not create an EncryptedMash object' do
      expect(@EncryptedMash).not_to receive(:new)
      @EncryptedAttribute.exists?([ 'a' ])
    end

    it 'should call EncryptedMash#exists? and return its result' do
      expect(@EncryptedMash).to receive(:exists?).with([ 'a' ]).and_return(true)
      expect(@EncryptedAttribute.exists?([ 'a' ])).to eql(true)
      expect(@EncryptedMash).to receive(:exists?).with([ 'a' ]).and_return(false)
      expect(@EncryptedAttribute.exists?([ 'a' ])).to eql(false)
    end

  end # context #exists?

  context '#self.exists_on_node?' do

    it 'should load the remote attribute and call #exists?' do
      expect_any_instance_of(@Config).to receive(:partial_search).and_return('partial_search')
      expect_any_instance_of(@RemoteNode).to receive(:load_attribute).with(['attr'], 'partial_search').and_return('load_attribute')
      expect(@EncryptedAttribute).to receive(:exists?).with('load_attribute').and_return('exists?')
      expect(@EncryptedAttribute.exists_on_node?('node1', ['attr'])).to eql('exists?')
    end

  end # context #self.exists_on_node?

end # describe Chef::EncryptedAttribute::Config
