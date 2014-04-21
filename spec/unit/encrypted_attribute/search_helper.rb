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

describe Chef::EncryptedAttribute::SearchHelper do
  before do
    @SearchHelper = Chef::EncryptedAttribute::SearchHelper
    Chef::Config[:client_key] = "#{File.dirname(__FILE__)}/../../data/client.pem"
  end

  context '#query' do

    it 'should return a Chef Search Query instance' do
       @SearchHelper.query.should be_a(Chef::Search::Query)
    end

    it 'should create a new instance each time called' do
      Chef::Search::Query.should_receive(:new).exactly(4).times
      (1..4).step.each { |x| @SearchHelper.query }
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
      '?var1=1&var2=2' => '%3Fvar1%3D1%26var2%3D2',
    }.each do |orig_str, escaped|

      it "should escape #{orig_str.inspect} properly" do
        @SearchHelper.escape(orig_str).should eql(escaped)
      end

    end # each do |orig_ster, escaped|

  end # context #escape

  context '#escape_query' do

    {
      'true' => true,
      'true' => 'true',
      '( a ) OR ( b )' => [ 'a', 'b' ],
      '( true ) OR ( ?var1=1&var2=2 ) OR ( slashed/text )' => [ true, '?var1=1&var2=2', 'slashed/text' ],
    }.each do |escaped, orig_str|

      it "should join with ORs and escape #{orig_str.inspect} properly" do
        @SearchHelper.escape_query(orig_str).should eql(@SearchHelper.escape(escaped))
      end

    end # each do |escaped, orig_str|

  end # context #escaped_query

  context '#valid_search_keys?' do

    [
      { 'public_key' => [ 'public_key' ] },
      { :cpu_flags => [ 'cpu', '0', 'flags' ] },
    ].each do |keys|

      it "should return true for #{keys.inspect}" do
        @SearchHelper.valid_search_keys?(keys).should eql(true)
      end

    end # each do |keys|

    [
      5, false, 'string',
      { 'public_key' => [ 0 ] },
      { :cpu_flags => [ 'cpu', '0', 'flags', 0 ] }, # not supported by chef server
      { 'common' => 'mistake' },
      { 'dvorak' => { :bad => 'hash' } },
    ].each do |bad_keys|

      it "should return false for #{bad_keys.inspect}" do
        @SearchHelper.valid_search_keys?(bad_keys).should eql(false)
      end

    end # each do |bad_keys|

  end # context #valid_search_keys?

  context '#search' do

    it 'should call #partial_search when partial_search=true' do
      @SearchHelper.should_receive(:partial_search).with(1, 2, 3, 4)
      @SearchHelper.search(1, 2, 3, 4, true)
    end

    it 'should call #normal_search when partial_search=false' do
      @SearchHelper.should_receive(:normal_search).with(1, 2, 3, 4)
      @SearchHelper.search(1, 2, 3, 4, false)
    end

  end

  context '#normal_search' do
    before do
      Chef::Search::Query.any_instance.stub(:search).and_return(
        [ [
          { 'attr1' => { 'subattr1'  => 'leo' }},
          { 'attr1'  => { 'subattr1' => :donnie }},
          { 'attr1' => begin # respond_to?(:subattr1)
              o = Object.new
              o.stub(:subattr1).and_return('ralph')
              o
            end
          },
          begin # node.attributes
            n = Chef::Node.new
            n.set[:attr1]['subattr1'] = 'mikey'
            n
          end,
        ] ]
      )
    end

    it 'should return search results without errors' do
      @SearchHelper.normal_search(:node, '*:*', { :value => [ 'attr1', 'subattr1' ] }).should eql([
        { :value => 'leo' },
        { :value => :donnie },
        { :value =>  'ralph' },
        { :value =>  'mikey' },
      ])
    end

    it 'should throw an error for invalid keys' do
      @SearchHelper.should_receive(:valid_search_keys?).and_return(false)
      lambda { @SearchHelper.normal_search(:node, '*:*', 'invalid_query') }.should raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
    end

    it 'should throw fatal error for invalid search results' do
      Chef::Search::Query.any_instance.should_receive(:search).and_return('bad result :(')
      lambda { @SearchHelper.normal_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    it 'should return empty result for HTTP Not Found errors' do
      Chef::Search::Query.any_instance.should_receive(:search).and_raise(
        Net::HTTPServerException.new('Net::HTTPServerException',
          Net::HTTPResponse.new('1.1', '404', 'Not Found')
        )
      )
      @SearchHelper.normal_search(:node, '*:*', { 'valid' => [ 'keys' ] }).should eql([])
    end

    it 'should throw search error for HTTP Server Exception errors' do
      Chef::Search::Query.any_instance.should_receive(:search).and_raise(Net::HTTPServerException.new('unit test', 0))
      lambda { @SearchHelper.normal_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFailure)
    end

    it 'should throw search error for HTTP Fatal errors' do
      Chef::Search::Query.any_instance.should_receive(:search).and_raise(Net::HTTPFatalError.new('unit test', 0))
      lambda { @SearchHelper.normal_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFailure)
    end

  end

  context '#partial_search' do
    before do
      Chef::REST.any_instance.stub(:post_rest).and_return(
        {
          'rows' => [
            {
              'data' =>
                { 'leo' => 'donnie' }
            },
            {
              'data' =>
                { 'raph' => 'mikey' }
            },
          ]
        }
      )
    end

    it 'should return search results without errors' do
      @SearchHelper.partial_search(:node, '*:*', { :D => [ 'valid_keys' ] }).should eql([
        { 'leo' => 'donnie' },
        { 'raph' => 'mikey' },
      ])
    end

    it 'should throw an error for invalid keys' do
      @SearchHelper.should_receive(:valid_search_keys?).and_return(false)
      lambda { @SearchHelper.partial_search(:node, '*:*', 'invalid_query') }.should raise_error(Chef::EncryptedAttribute::InvalidSearchKeys)
    end

    it 'should throw fatal error for invalid search results' do
      Chef::REST.any_instance.should_receive(:post_rest).and_return({ 'rows' => ':(' })
      lambda { @SearchHelper.partial_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    it 'should throw fatal error for invalid row results' do
      Chef::REST.any_instance.should_receive(:post_rest).and_return({ 'rows' => [ 'bad_data' => ':(' ] })
      lambda { @SearchHelper.partial_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFatalError)
    end

    it 'should return empty result for HTTP Not Found errors' do
      Chef::REST.any_instance.should_receive(:post_rest).and_raise(
        Net::HTTPServerException.new('Net::HTTPServerException',
          Net::HTTPResponse.new('1.1', '404', 'Not Found')
        )
      )
      @SearchHelper.partial_search(:node, '*:*', { 'valid' => [ 'keys' ] }).should eql([])
    end

    it 'should throw search error for HTTP Server Exception errors' do
      Chef::REST.any_instance.should_receive(:post_rest).and_raise(Net::HTTPServerException.new('unit test', 0))
      lambda { @SearchHelper.partial_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFailure)
    end

    it 'should throw search error for HTTP Fatal errors' do
      Chef::REST.any_instance.should_receive(:post_rest).and_raise(Net::HTTPFatalError.new('unit test', 0))
      lambda { @SearchHelper.partial_search(:node, '*:*', { 'valid' => [ 'keys' ] }) }.should raise_error(Chef::EncryptedAttribute::SearchFailure)
    end

  end

end
