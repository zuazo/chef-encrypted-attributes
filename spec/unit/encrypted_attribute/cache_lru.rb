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

describe Chef::EncryptedAttribute::CacheLru do
  let(:cache_lru_class) { Chef::EncryptedAttribute::CacheLru }

  describe '#new' do
    it 'creates a cache without errors' do
      expect { cache_lru_class.new }.not_to raise_error
    end

    it 'creates a cache with max_size as argument ' do
      expect_any_instance_of(cache_lru_class)
        .to receive(:max_size).with(25).once
      cache_lru_class.new(25)
    end
  end

  describe '#max_size' do
    it 'returns 1024 by default' do
      cache = cache_lru_class.new
      expect(cache.max_size).to eql(1024)
    end

    it 'is able to change the maximum size' do
      cache = cache_lru_class.new
      expect(cache.max_size(25)).to eql(25)
      expect(cache.max_size).to eql(25)
    end

    it 'reduces the cache size if max_size is decreased' do
      cache = cache_lru_class.new(25)
      (1..25).step.each { |x| cache[x.to_s] = x }
      expect(cache.size).to eql(25)
      cache.max_size(10)
      expect(cache.size).to eql(10)
    end
  end

  describe '#[]' do
    let(:cache) { cache_lru_class.new(10) }
    before { cache['key1'] = 'value1' }

    it 'reads a cache value' do
      expect(cache['key1']).to eql('value1')
    end

    it 'returns nil if the key does not exist' do
      expect(cache['key2']).to eql(nil)
    end
  end

  describe '#[]=' do
    let(:cache) { cache_lru_class.new(10) }

    it 'sets a cache value' do
      cache['key1'] = 'value1'
      expect(cache['key1']).to eql('value1')
    end

    it 'does not set more than max_size values' do
      (1..20).step.each { |x| cache[x.to_s] = x }
      expect(cache.size).to eql(10)
    end

    it 'frees items using LRU algorithm' do
      # add 1..10
      (1..10).step.each { |x| cache[x] = x }
      # refresh 4..8
      (4..8).step.each { |x| cache[x] }
      # add 11..14
      (11..14).step.each { |x| cache[x] = x }

      # expectations
      (1..3).step.each { |x| expect(cache.key?(x)).to be_falsey }
      (4..8).step.each { |x| expect(cache.key?(x)).to be_truthy }
      (10..14).step.each { |x| expect(cache.key?(x)).to be_truthy }
    end
  end
end
