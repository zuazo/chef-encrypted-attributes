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

describe Chef::EncryptedAttribute::EncryptedMash do
  before(:all) do
    Chef::EncryptedAttribute::RemoteClients.cache.clear
    Chef::EncryptedAttribute::RemoteUsers.cache.clear
  end
  before do
    @EncryptedMash = Chef::EncryptedAttribute::EncryptedMash
  end

  context '#new' do

    it 'should create an EncryptedMash object without errors' do
      lambda { @EncryptedMash.new }.should_not raise_error
    end

    it 'should be able to create an EncryptedMash from another EncryptedMash instance passed as arg' do
      body0 = @EncryptedMash.new
      @EncryptedMash.any_instance.should_receive(:update_from!).with(body0)
      lambda { @EncryptedMash.new(body0) }.should_not raise_error
    end

    %w{encrypt decrypt can_be_decrypted_by? needs_update?}.each do |meth|

      it "##{meth} method should raise a NotImplementedError error" do
        body = @EncryptedMash.new
        lambda { body.send(meth) }.should raise_error(NotImplementedError)
      end

    end # each do |meth|

  end # context #new

  context '#self.exists' do

    @EncryptedMash = Chef::EncryptedAttribute::EncryptedMash
    [
      @EncryptedMash.new,
      {
        @EncryptedMash::JSON_CLASS => @EncryptedMash.to_s,
        @EncryptedMash::CHEF_TYPE => @EncryptedMash::CHEF_TYPE_VALUE,
      },
    ].each do |o|
      it "should return true for #{o.inspect}" do
        @EncryptedMash.exists?(o).should be_true
      end
    end

    [
      5, true, {},
      { @EncryptedMash::JSON_CLASS => @EncryptedMash.name },
      {
        @EncryptedMash::JSON_CLASS => @EncryptedMash.name,
        @EncryptedMash::CHEF_TYPE => 'bad_type',
      },
    ].each do |o|
      it "should return false for #{o.inspect}" do
        @EncryptedMash.exists?(o).should be_false
      end
    end

  end # context #self.exists

  context '#self.create' do

    it 'should create a EncryptedMash subclass object' do
      o = @EncryptedMash.create(0)
      o.should be_kind_of(@EncryptedMash)
      o.should_not be_an_instance_of(@EncryptedMash)
    end

    it 'should throw an Unsupported exception for unknown versions' do
      Chef::Log.stub(:error) # silence Chef::Log.error by EncryptedMash#string_to_klass
      lambda { @EncryptedMash.create(1000) }.should raise_error(Chef::EncryptedAttribute::UnsupportedEncryptedAttributeFormat)
    end

    [ nil, ''].each do |version|
      it "should throw an Unacceptable exception for #{version.inspect} versions" do
        lambda { @EncryptedMash.create(version) }.should raise_error(Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat)
      end
    end

    it 'should use #const_get in a Ruby 1.8 compatible way' do
      stub_const('RUBY_VERSION', '1.8.7')
      Kernel.should_receive(:const_get).with('Chef').once.and_return(Chef)
      @EncryptedMash.create(0)
    end

    it 'should use #const_get in a Ruby 1.9 compatible way', :if => RUBY_VERSION >= '1.9' do
      stub_const('RUBY_VERSION', '1.9.0')
      Kernel.should_receive(:const_get).with('Chef', true).once.and_return(Chef)
      @EncryptedMash.create(0)
    end

  end # context #self.create

  context '#to_json' do

    it 'should return a JSON object' do
      o = @EncryptedMash.create(0)
      o.to_json.should eql(o.to_hash.to_json)
    end

    it 'should pass arguments to Hash#to_json method' do
      o = @EncryptedMash.create(0)
      @EncryptedMash.any_instance.should_receive(:for_json).and_return(o.to_hash)
      Hash.any_instance.should_receive(:to_json).with(1, 2, 3, 4)
      o.to_json(1, 2, 3, 4)
    end

  end # context #to_json

  context '#for_json' do

    it 'should return a Hash object' do
      o = @EncryptedMash.new
      o.for_json.should be_instance_of(Hash)
      o.for_json.should eql(o.to_hash)
    end

  end # context #for_json

  context '#update_from!' do

    it 'should update the encrypted attribute from another encrypted attribute' do
      orig = @EncryptedMash.new
      orig['key1'] = 'value1'
      new = @EncryptedMash.new
      new.update_from!(orig)
      new['key1'].should eql('value1')
    end

    it 'should throw an error if a wrong encrypted attribute is passed as arg' do
      o = @EncryptedMash.new
      lambda { o.update_from!({}) }.should raise_error(Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat)
    end

  end # context #update_from!

  context '#self.json_create' do

    it 'should create a new object from a JSON Hash' do
      orig = @EncryptedMash.new
      orig['key1'] = 'value1'
      new = @EncryptedMash.json_create(orig)
      new.should be_kind_of(@EncryptedMash)
      new.should_not equal(orig)
      new['key1'].should eql('value1')
    end

    it 'should throw an error if empty attribute is passed as arg' do
      Chef::Log.stub(:error) # silence Chef::Log.error by EncryptedMash#string_to_klass
      lambda { @EncryptedMash.json_create({}) }.should raise_error(Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat)
    end

    it 'should throw an error if a wrong encrypted attribute is passed as arg' do
      Chef::Log.stub(:error) # silence Chef::Log.error by EncryptedMash#string_to_klass
      lambda { @EncryptedMash.json_create({
        @EncryptedMash::JSON_CLASS => 'NonExistent::Class',
      }) }.should raise_error(Chef::EncryptedAttribute::UnsupportedEncryptedAttributeFormat)
    end

  end # context #self.json_create

end # describe Chef::EncryptedAttribute::EncryptedMash
