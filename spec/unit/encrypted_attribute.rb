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
    Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client_key)

    @EncryptedAttribute = Chef::EncryptedAttribute
    @EncryptedMash = Chef::EncryptedAttribute::EncryptedMash
    @Config = Chef::EncryptedAttribute::Config
  end

  context '#self.create' do
    before do
      @EncryptedAttribute.any_instance.stub(:create)
    end

    it 'should create an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      @EncryptedAttribute.should_receive(:new).and_return(body)
      @EncryptedAttribute.create([ 'a' ])
    end

    it 'should create an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      @EncryptedAttribute.should_receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.create([ 'a' ], custom_config)
    end

    it "should call EncryptedAttribute#create and return its result" do
      @EncryptedAttribute.any_instance.should_receive(:create).with([ 'a' ]).and_return('create')
      @EncryptedAttribute.create([ 'a' ]).should eql('create')
    end

  end # context #self.create

  xit '#self.create_on_node'

  %w{load update}.each do |meth|

    context "#self.#{meth}" do
      before do
        @EncryptedAttribute.any_instance.stub(meth.to_sym)
      end

      it 'should create an EncryptedAttribute object' do
        body = @EncryptedAttribute.new
        @EncryptedAttribute.should_receive(:new).and_return(body)
        @EncryptedAttribute.send(meth, [ 'a' ])
      end

      it 'should create an EncryptedAttribute object with a custom config' do
        orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
        custom_config = @Config.new({ :partial_search => false })
        body = @EncryptedAttribute.new
        @EncryptedAttribute.should_receive(:new).with(an_instance_of(@Config)).once.and_return(body)
        @EncryptedAttribute.send(meth, [ 'a' ], custom_config)
      end

      it "should call EncryptedAttribute##{meth} and return its result" do
        @EncryptedAttribute.any_instance.should_receive(meth.to_sym).with([ 'a' ]).and_return("#{meth}")
        @EncryptedAttribute.send(meth, [ 'a' ]).should eql("#{meth}")
      end

    end # context #self.meth

  end # %w{load update}.each do |meth|

  context '#self.load_from_node' do
    before do
      @EncryptedAttribute.any_instance.stub(:load_from_node)
    end

    it 'should create an EncryptedAttribute object' do
      body = @EncryptedAttribute.new
      @EncryptedAttribute.should_receive(:new).and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ])
    end

    it 'should create an EncryptedAttribute object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedAttribute.new
      @EncryptedAttribute.should_receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ], custom_config)
    end

    it 'should call EncryptedAttribute#load_from_node and return its result' do
      @EncryptedAttribute.any_instance.should_receive(:load_from_node).with('node1', [ 'a' ]).and_return('load_from_node')
      @EncryptedAttribute.load_from_node('node1', [ 'a' ]).should eql('load_from_node')
    end

  end # context #load_from_node

  context '#self.exists?' do
    before do
      @EncryptedMash.any_instance.stub(:exists?)
    end

    it 'should not create an EncryptedMash object' do
      @EncryptedMash.should_not_receive(:new)
      @EncryptedAttribute.exists?([ 'a' ])
    end

    it 'should call EncryptedMash#exists? and return its result' do
      @EncryptedMash.should_receive(:exists?).with([ 'a' ]).and_return(true)
      @EncryptedAttribute.exists?([ 'a' ]).should eql(true)
      @EncryptedMash.should_receive(:exists?).with([ 'a' ]).and_return(false)
      @EncryptedAttribute.exists?([ 'a' ]).should eql(false)
    end

  end # context #exists?

  xit '#self.exists_on_node?'

end # describe Chef::EncryptedAttribute::Config
