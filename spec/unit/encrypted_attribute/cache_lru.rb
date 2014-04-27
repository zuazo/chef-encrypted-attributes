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

describe Chef::EncryptedAttribute::CacheLru do
  before do
    @CacheLru = Chef::EncryptedAttribute::CacheLru
  end

  describe '#new' do

    it 'should create a cache without errors' do
      lambda { @CacheLru.new }.should_not raise_error
    end

    it 'should a cache with max_size as argument ' do
      @CacheLru.any_instance.should_receive(:max_size).with(25).once
      @CacheLru.new(25)
    end

  end

  describe '#max_size' do

    it 'should return 1024 by default' do
      cache = @CacheLru.new
      cache.max_size.should eql(1024)
    end

    it 'should be able to change the maximum size' do
      cache = @CacheLru.new
      cache.max_size(25).should eql(25)
      cache.max_size.should eql(25)
    end

    it 'should reduce the cache size if max_size is decreased' do
      cache = @CacheLru.new(25)
      (1..25).step.each do |x|
        cache[x.to_s] = x
      end
      cache.size.should eql(25)
      cache.max_size(10)
      cache.size.should eql(10)
    end

  end

  describe '#[]' do
    before do
      @cache = @CacheLru.new(10)
      @cache['key1'] = 'value1'
    end

    it 'should read a cache value' do
      @cache['key1'].should eql('value1')
    end

    it 'should return nil if the key does not exist' do
      @cache['key2'].should eql(nil)
    end

  end

  describe '#[]=' do
    before do
      @cache = @CacheLru.new(10)
    end

    it 'should set a cache value' do
      @cache['key1'] = 'value1'
      @cache['key1'].should eql('value1')
    end

    it 'should not set more than max_size values' do
      (1..20).step.each do |x|
        @cache[x.to_s] = x
      end
      @cache.size.should eql(10)
    end

    it 'should free items using LRU algorithm' do
      # add 1..10
      (1..10).step.each { |x| @cache[x] = x }
      # refresh 4..8
      (4..8).step.each { |x| read = @cache[x] }
      # add 11..14
      (11..14).step.each { |x| @cache[x] = x }

      # expectations
      (1..3).step.each { |x| @cache.has_key?(x).should be_false }
      (4..8).step.each { |x| @cache.has_key?(x).should be_true }
      (10..14).step.each { |x| @cache.has_key?(x).should be_true }
    end

  end

end
