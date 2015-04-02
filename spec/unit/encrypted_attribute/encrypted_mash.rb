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

describe Chef::EncryptedAttribute::EncryptedMash do
  encrypted_mash_class = described_class
  before(:all) { clear_all_caches }

  context '#new' do
    it 'creates an EncryptedMash object without errors' do
      expect { encrypted_mash_class.new }.not_to raise_error
    end

    it 'is able to create an EncryptedMash from another EncryptedMash '\
       'instance passed as arg' do
      body0 = encrypted_mash_class.new
      expect_any_instance_of(encrypted_mash_class)
        .to receive(:update_from!).with(body0)
      expect { encrypted_mash_class.new(body0) }.not_to raise_error
    end

    %w(encrypt decrypt can_be_decrypted_by? needs_update?).each do |meth|
      it "##{meth} method raises a NotImplementedError error" do
        body = encrypted_mash_class.new
        expect { body.send(meth) }.to raise_error(NotImplementedError)
      end
    end # each do |meth|
  end # context #new

  context '#self.exist?' do
    [
      encrypted_mash_class.new,
      {
        encrypted_mash_class::JSON_CLASS => encrypted_mash_class.to_s,
        encrypted_mash_class::CHEF_TYPE => encrypted_mash_class::CHEF_TYPE_VALUE
      }
    ].each do |o|
      it "returns true for #{o.inspect}" do
        expect(Chef::Log).to_not receive(:warn)
        expect(encrypted_mash_class.exist?(o)).to be_truthy
      end
    end

    [
      5, true, {},
      { encrypted_mash_class::JSON_CLASS => encrypted_mash_class.name },
      {
        encrypted_mash_class::JSON_CLASS => encrypted_mash_class.name,
        encrypted_mash_class::CHEF_TYPE => 'bad_type'
      }
    ].each do |o|
      it "returns false for #{o.inspect}" do
        expect(Chef::Log).to_not receive(:warn)
        expect(encrypted_mash_class.exist?(o)).to be_falsey
      end
    end
  end # context #self.exist?

  context '#self.exists?' do
    [
      encrypted_mash_class.new,
      {
        encrypted_mash_class::JSON_CLASS => encrypted_mash_class.to_s,
        encrypted_mash_class::CHEF_TYPE => encrypted_mash_class::CHEF_TYPE_VALUE
      }
    ].each do |o|
      it "returns true for #{o.inspect}" do
        expect(Chef::Log)
          .to receive(:warn).once.with(/is deprecated in favor of/)
        expect(encrypted_mash_class.exists?(o)).to be_truthy
      end
    end

    [
      5, true, {},
      { encrypted_mash_class::JSON_CLASS => encrypted_mash_class.name },
      {
        encrypted_mash_class::JSON_CLASS => encrypted_mash_class.name,
        encrypted_mash_class::CHEF_TYPE => 'bad_type'
      }
    ].each do |o|
      it "returns false for #{o.inspect}" do
        expect(Chef::Log)
          .to receive(:warn).once.with(/is deprecated in favor of/)
        expect(encrypted_mash_class.exists?(o)).to be_falsey
      end
    end
  end # context #self.exists?

  context '#self.create' do
    it 'creates a EncryptedMash subclass object' do
      o = encrypted_mash_class.create(0)
      expect(o).to be_kind_of(encrypted_mash_class)
      expect(o).not_to be_an_instance_of(encrypted_mash_class)
    end

    it 'throws an Unsupported exception for unknown versions' do
      # silence Chef::Log.error by EncryptedMash#string_to_klass
      allow(Chef::Log).to receive(:error)
      expect { encrypted_mash_class.create(1000) }
        .to raise_error(
          Chef::EncryptedAttribute::UnsupportedEncryptedAttributeFormat
        )
    end

    [nil, ''].each do |version|
      it "throws an Unacceptable exception for #{version.inspect} versions" do
        expect { encrypted_mash_class.create(version) }
          .to raise_error(
            Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat
          )
      end
    end

    it 'uses #const_get in a Ruby 1.9 compatible way' do
      expect(Kernel)
        .to receive(:const_get).with('Chef', true).once.and_return(Chef)
      encrypted_mash_class.create(0)
    end
  end # context #self.create

  context '#to_json' do
    it 'returns a JSON object' do
      o = encrypted_mash_class.create(0)
      expect(o.to_json).to eql(o.to_hash.to_json)
    end

    it 'passes arguments to Hash#to_json method' do
      o = encrypted_mash_class.create(0)
      expect_any_instance_of(encrypted_mash_class)
        .to receive(:for_json).and_return(o.to_hash)
      expect_any_instance_of(Hash).to receive(:to_json).with(1, 2, 3, 4)
      o.to_json(1, 2, 3, 4)
    end
  end # context #to_json

  context '#for_json' do
    it 'returns a Hash object' do
      o = encrypted_mash_class.new
      expect(o.for_json).to be_instance_of(Hash)
      expect(o.for_json).to eql(o.to_hash)
    end
  end # context #for_json

  context '#update_from!' do
    it 'updates the encrypted attribute from another encrypted attribute' do
      orig = encrypted_mash_class.new
      orig['key1'] = 'value1'
      new = encrypted_mash_class.new
      new.update_from!(orig)
      expect(new['key1']).to eql('value1')
    end

    it 'throws an error if a wrong encrypted attribute is passed as arg' do
      o = encrypted_mash_class.new
      expect { o.update_from!({}) }
        .to raise_error(
          Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat
        )
    end
  end # context #update_from!

  context '#self.json_create' do
    it 'creates a new object from a JSON Hash' do
      orig = encrypted_mash_class.new
      orig['key1'] = 'value1'
      new = encrypted_mash_class.json_create(orig)
      expect(new).to be_kind_of(encrypted_mash_class)
      expect(new).not_to equal(orig)
      expect(new['key1']).to eql('value1')
    end

    it 'throws an error if wrong attribute is passed as arg' do
      # silence Chef::Log.error by EncryptedMash#string_to_klass
      allow(Chef::Log).to receive(:error)
      expect { encrypted_mash_class.json_create(nil) }
        .to raise_error(
          Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat,
          'Encrypted attribute not found or corrupted.'
        )
    end

    it 'throws an error if empty attribute is passed as arg' do
      # silence Chef::Log.error by EncryptedMash#string_to_klass
      allow(Chef::Log).to receive(:error)
      expect { encrypted_mash_class.json_create({}) }
        .to raise_error(
          Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat
        )
    end

    it 'throws an error if a wrong encrypted attribute is passed as arg' do
      # silence Chef::Log.error by EncryptedMash#string_to_klass
      allow(Chef::Log).to receive(:error)
      expect do
        encrypted_mash_class.json_create(
          encrypted_mash_class::JSON_CLASS => 'NonExistent::Class'
        )
      end.to raise_error(
        Chef::EncryptedAttribute::UnsupportedEncryptedAttributeFormat
      )
    end
  end # context #self.json_create
end # describe Chef::EncryptedAttribute::EncryptedMash
