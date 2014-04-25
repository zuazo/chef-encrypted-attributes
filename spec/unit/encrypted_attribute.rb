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
  before do
    @EncryptedAttribute = Chef::EncryptedAttribute
    @EncryptedMash = Chef::EncryptedAttribute::EncryptedMash
    @Config = Chef::EncryptedAttribute::Config
  end

  %w{load create update}.each do |meth|

    context "##{meth}" do
      before do
        @EncryptedMash.any_instance.stub(meth.to_sym)
      end

      it 'should create an EncryptedMash object' do
        body = @EncryptedMash.new
        @EncryptedMash.should_receive(:new).and_return(body)
        Chef::Config.should_receive(:[]).with(:encrypted_attributes).once.and_return(nil)
        @EncryptedAttribute.send(meth, [ 'a' ])
      end

      it 'should create an EncryptedMash object with a custom config' do
        orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
        custom_config = @Config.new({ :partial_search => false })
        body = @EncryptedMash.new
        @EncryptedMash.should_receive(:new).with(an_instance_of(@Config)).once.and_return(body)
        @EncryptedAttribute.send(meth, [ 'a' ], custom_config)
      end

      it "should call EncryptedMash##{meth} and return its result" do
        @EncryptedMash.any_instance.should_receive(meth.to_sym).with([ 'a' ]).and_return("#{meth}")
        @EncryptedAttribute.send(meth, [ 'a' ]).should eql("#{meth}")
      end

    end # context #meth

  end # each do |meth|

  context '#load_from_node' do
    before do
      @EncryptedMash.any_instance.stub(:load_from_node)
    end

    it 'should create an EncryptedMash object' do
      body = @EncryptedMash.new
      @EncryptedMash.should_receive(:new).and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ])
    end

    it 'should create an EncryptedMash object with a custom config' do
      orig_config = Chef::Config[:encrypted_attributes] = { :partial_search => true }
      custom_config = @Config.new({ :partial_search => false })
      body = @EncryptedMash.new
      @EncryptedMash.should_receive(:new).with(an_instance_of(@Config)).once.and_return(body)
      @EncryptedAttribute.load_from_node('node1', [ 'a' ], custom_config)
    end

    it 'should call EncryptedMash#load_from_node and return its result' do
      @EncryptedMash.any_instance.should_receive(:load_from_node).with('node1', [ 'a' ]).and_return('load_from_node')
      @EncryptedAttribute.load_from_node('node1', [ 'a' ]).should eql('load_from_node')
    end

  end # context #load_from_node

  context '#exists?' do
    before do
      @EncryptedMash.any_instance.stub(:exists?)
    end

    it 'should not create an EncryptedMash object' do
      @EncryptedMash.should_not_receive(:new)
    end

    it 'should call EncryptedMash#exists? and return its result' do
      @EncryptedMash.should_receive(:exists?).with([ 'a' ]).and_return('exists?')
      @EncryptedAttribute.exists?([ 'a' ]).should eql('exists?')
    end

  end # context #exists?

end # describe Chef::EncryptedAttribute::Config
