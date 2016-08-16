# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014-2015 Onddo Labs, SL. (www.onddo.com)
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
require 'chef/node'

describe Chef::EncryptedAttribute::SearchHelper do
  let(:search_helper_class) { Chef::EncryptedAttribute::SearchHelper }
  before do
    @prev_client_key = Chef::Config[:client_key]
    Chef::Config[:client_key] =
      "#{File.dirname(__FILE__)}/../../data/client.pem"
  end
  after(:all) { Chef::Config[:client_key] = @prev_client_key }

  context '#query' do
    it 'returns a Chef Search Query instance' do
      expect(search_helper_class.query).to be_a(Chef::Search::Query)
    end

    it 'creates a new instance each time called' do
      expect(Chef::Search::Query).to receive(:new).exactly(4).times
      (1..4).step.each { |_x| search_helper_class.query }
    end
  end # context #query

  context '#escape' do
    {
      'clear' => 'clear',
      'dashed-text' => 'dashed-text',
      'underscored_text' => 'underscored_text',
      'spaced text ' => 'spaced%20text%20',
      'slashed/text' => 'slashed%2Ftext',
      '%20' => '%2520',
      'http://onddo.com' => 'http%3A%2F%2Fonddo.com',
      '?var1=1' => '%3Fvar1%3D1',
      '?var1=1&var2=2' => '%3Fvar1%3D1%26var2%3D2'
    }.each do |orig_str, escaped|
      it "escapes #{orig_str.inspect} properly" do
        expect(search_helper_class.escape(orig_str)).to eql(escaped)
      end
    end # each do |orig_ster, escaped|
  end # context #escape

  context '#escape_query' do
    {
      'true' => true,
      'true' => 'true',
      '( a ) OR ( b )' => %w(a b),
      '( true ) OR ( ?var1=1&var2=2 ) OR ( slashed/text )' =>
        [true, '?var1=1&var2=2', 'slashed/text']
    }.each do |escaped, orig_str|
      it "joins with ORs and escape #{orig_str.inspect} properly" do
        expect(search_helper_class.escape_query(orig_str))
          .to eql(search_helper_class.escape(escaped))
      end
    end # each do |escaped, orig_str|
  end # context #escaped_query

  context '#valid_search_keys?' do
    [
      { 'public_key' => %w(public_key) },
      { cpu_flags: %w(cpu 0 flags) }
    ].each do |keys|
      it "returns true for #{keys.inspect}" do
        expect(search_helper_class.valid_search_keys?(keys)).to eql(true)
      end
    end # each do |keys|

    [
      5, false, 'string',
      { 'public_key' => [0] },
      { cpu_flags: ['cpu', '0', 'flags', 0] }, # not supported by chef server
      { 'common' => 'mistake' },
      { 'dvorak' => { bad: 'hash' } }
    ].each do |bad_keys|
      it "returns false for #{bad_keys.inspect}" do
        expect(search_helper_class.valid_search_keys?(bad_keys)).to eql(false)
      end
    end # each do |bad_keys|
  end # context #valid_search_keys?

  context '#search' do
    it 'does not search for empty searches' do
      expect(search_helper_class).not_to receive(:partial_search)
      expect(search_helper_class).not_to receive(:normal_search)
      search_helper_class.search(1, [], 3, 4, true)
    end

    it 'calls #partial_search when partial_search=true' do
      expect(search_helper_class)
        .to receive(:partial_search).with(1, nil, 2, 3, 4)
      search_helper_class.search(1, 2, 3, 4, true)
    end

    it 'calls #normal_search when partial_search=false' do
      expect(search_helper_class)
        .to receive(:normal_search).with(1, nil, 2, 3, 4)
      search_helper_class.search(1, 2, 3, 4, false)
    end

    context 'with normal search' do
      it 'returns empty result for HTTP Not Found errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(
            Net::HTTPServerException.new(
              'Net::HTTPServerException',
              Net::HTTPResponse.new('1.1', '404', 'Not Found')
            )
          )
        expect(
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, false
          )
        ).to eql([])
      end

      it 'throws search error for HTTP Server Exception errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(Net::HTTPServerException.new('unit test', 0))
        expect do
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, false
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end

      it 'throws search error for HTTP Fatal errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(Net::HTTPFatalError.new('unit test', 0))
        expect do
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, false
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end
    end # with normal search

    context 'with partial search' do
      it 'returns empty result for HTTP Not Found errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(
            Net::HTTPServerException.new(
              'Net::HTTPServerException',
              Net::HTTPResponse.new('1.1', '404', 'Not Found')
            )
          )
        expect(
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, true
          )
        ).to eql([])
      end

      it 'throws search error for HTTP Server Exception errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(Net::HTTPServerException.new('unit test', 0))
        expect do
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, true
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end

      it 'throws search error for HTTP Fatal errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(Net::HTTPFatalError.new('unit test', 0))
        expect do
          search_helper_class.search(
            :node, '*:*', { 'valid' => %w(keys) }, 1000, true
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end
    end # with partial search
  end # #search

  context '#search_by_name' do
    it 'calls #partial_search when partial_search=true' do
      expect(search_helper_class)
        .to receive(:partial_search).with(1, 2, 'name:2', 3, 4)
      search_helper_class.search_by_name(1, 2, 3, 4, true)
    end

    it 'calls #normal_search when partial_search=false' do
      expect(search_helper_class)
        .to receive(:normal_search).with(1, 2, 'name:2', 3, 4)
      search_helper_class.search_by_name(1, 2, 3, 4, false)
    end

    context 'with normal search' do
      it 'returns empty result for HTTP Not Found errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(
            Net::HTTPServerException.new(
              'Net::HTTPServerException',
              Net::HTTPResponse.new('1.1', '404', 'Not Found')
            )
          )
        expect(
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, false
          )
        ).to eql([])
      end

      it 'throws search error for HTTP Server Exception errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(Net::HTTPServerException.new('unit test', 0))
        expect do
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, false
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end

      it 'throws search error for HTTP Fatal errors' do
        expect_any_instance_of(Chef::Search::Query).to receive(:search)
          .and_raise(Net::HTTPFatalError.new('unit test', 0))
        expect do
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, false
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end
    end # with normal search

    context 'with partial search' do
      it 'returns empty result for HTTP Not Found errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(
            Net::HTTPServerException.new(
              'Net::HTTPServerException',
              Net::HTTPResponse.new('1.1', '404', 'Not Found')
            )
          )
        expect(
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, true
          )
        ).to eql([])
      end

      it 'throws search error for HTTP Server Exception errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(Net::HTTPServerException.new('unit test', 0))
        expect do
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, true
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end

      it 'throws search error for HTTP Fatal errors' do
        expect_any_instance_of(Chef::ServerAPI).to receive(:post)
          .and_raise(Net::HTTPFatalError.new('unit test', 0))
        expect do
          search_helper_class.search_by_name(
            :node, 'node1', { 'valid' => %w(keys) }, 1000, true
          )
        end.to raise_error(Chef::EncryptedAttribute::SearchFailure)
      end
    end # with partial search
  end # #search_by_name

  context '#normal_search' do
    before do
      allow_any_instance_of(Chef::Search::Query).to receive(:search).and_return(
        [[
          { 'attr1' => { 'subattr1'  => 'leo' } },
          { 'attr1'  => { 'subattr1' => :donnie } },
          { 'attr1' =>
            # respond_to?(:subattr1)
            Object.new.tap do |o|
              allow(o).to receive(:subattr1).and_return('ralph')
            end
          },
          # node.attributes
          Chef::Node.new.tap { |n| n.set[:attr1]['subattr1'] = 'mikey' }
        ]]
      )
    end

    it 'returns search results without errors' do
      expect(
        search_helper_class.normal_search(
          :node, nil, '*:*', value: %w(attr1 subattr1)
        )
      ).to eql(
        [
          { value: 'leo' },
          { value: :donnie },
          { value: 'ralph' },
          { value: 'mikey' }
        ]
      )
    end

    it 'throws an error for invalid keys' do
      expect(search_helper_class)
        .to receive(:valid_search_keys?).and_return(false)
      expect do
        search_helper_class.normal_search(:node, nil, '*:*', 'invalid_query')
      end.to raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
    end

    it 'throws fatal error for invalid search results' do
      expect_any_instance_of(Chef::Search::Query)
        .to receive(:search).and_return('bad result :(')
      expect do
        search_helper_class
          .normal_search(:node, nil, '*:*', 'valid' => %w(keys))
      end.to raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    context 'searching by name' do
      before do
        allow_any_instance_of(Chef::Search::Query)
          .to receive(:search).and_return(
            [[
              Chef::Node.new.tap do |n|
                n.name('node1')
                n.set[:attr1]['subattr1'] = 'leo'
              end,
              Chef::Node.new.tap do |n|
                n.name('node2')
                n.set[:attr1]['name'] = 'node1' # GitHub issue #3
                n.set[:attr1]['subattr1'] = 'donnie'
              end
            ]]
          )
      end

      it 'returns search results without errors' do
        expect(
          search_helper_class.normal_search(
            :node, 'node1', 'name:node1', value: %w(attr1 subattr1)
          )).to eql([value: 'leo'])
      end

      it 'throws fatal error if returns multiple results' do
        allow_any_instance_of(Chef::Search::Query)
          .to receive(:search).and_return(
            [[
              Chef::Node.new.tap do |n|
                n.name('node1')
                n.set[:attr1]['subattr1'] = 'leo'
              end,
              Chef::Node.new.tap do |n|
                n.name('node1')
                n.set[:attr1]['subattr1'] = 'donnie'
              end
            ]]
          )
        expect do
          search_helper_class
            .normal_search(:node, 'node1', 'name:node1', 'valid' => %w(keys))
        end.to raise_error(Chef::EncryptedAttribute::SearchFatalError)
      end
    end # searching by name
  end # #normal_search

  context '#partial_search' do
    before do
      allow_any_instance_of(Chef::ServerAPI).to receive(:post).and_return(
        'rows' => [
          { 'data' => { 'leo' => 'donnie' } },
          { 'data' => { 'raph' => 'mikey' } }
        ]
      )
    end

    it 'returns search results without errors' do
      expect(
        search_helper_class.partial_search(
          :node, nil, '*:*', D: %w(valid_keys)
        )
      ).to eql(
        [
          { 'leo' => 'donnie' },
          { 'raph' => 'mikey' }
        ]
      )
    end

    it 'throws an error for invalid keys' do
      expect(search_helper_class)
        .to receive(:valid_search_keys?).and_return(false)
      expect do
        search_helper_class.partial_search(:node, nil, '*:*', 'invalid_query')
      end.to raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
    end

    it 'throws fatal error for invalid search results' do
      expect_any_instance_of(Chef::ServerAPI)
        .to receive(:post).and_return('rows' => ':(')
      expect do
        search_helper_class
          .partial_search(:node, nil, '*:*', 'valid' => %w(keys))
      end.to raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    it 'throws fatal error for invalid row results' do
      expect_any_instance_of(Chef::ServerAPI)
        .to receive(:post).and_return('rows' => ['bad_data' => ':('])
      expect do
        search_helper_class
          .partial_search(:node, nil, '*:*', 'valid' => %w(keys))
      end.to raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    context 'searching by name' do
      before do
        allow_any_instance_of(Chef::ServerAPI)
          .to receive(:post).and_return(
            'rows' => [
              { 'data' => { 'leo' => 'donnie', 'name' => 'node1' } },
              { 'data' => { 'raph' => 'mikey', 'name' => 'node2' } }
              # GH issue #3
            ]
          )
      end

      it 'returns search results without errors' do
        expect(
          search_helper_class.partial_search(
            :node, 'node1', 'name:node1', D: %w(valid_keys)
          )
        ).to eql(['leo' => 'donnie'])
      end

      it 'throws fatal error if returns multiple results' do
        allow_any_instance_of(Chef::ServerAPI)
          .to receive(:post).and_return(
            'rows' => [
              { 'data' => { 'leo' => 'donnie', 'name' => 'node1' } },
              { 'data' => { 'raph' => 'mikey', 'name' => 'node1' } }
            ]
          )
        expect do
          search_helper_class
            .partial_search(:node, 'node1', 'name:node1', 'valid' => %w(keys))
        end.to raise_error(Chef::EncryptedAttribute::SearchFatalError)
      end
    end # searching by name
  end # #partial_search
end
