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

require 'chef/search/query'
require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    # Search Helpers to do normal or partial searches.
    module SearchHelper
      extend self

      # Gets a Chef Search Query object.
      #
      # @return {Chef::Search::Query} seqrch query object instance.
      # @api private
      def query
        Chef::Search::Query.new
      end

      # Escapes a search query string to be used in URLs.
      #
      # @param str [String] query to escape.
      # @return [String] escaped query string.
      # @api private
      def escape(str)
        URI.escape(str.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end

      # Escapes a search query array.
      #
      # When multiple queries are provided, the result will be *OR*-ed.
      #
      # @param query [Array<String>, String] search query.
      # @return [String] escaped query string.
      def escape_query(query)
        query_s =
          if query.is_a?(Array)
            query.map { |item| "( #{item} )" }.compact.join(' OR ')
          else
            query.to_s
          end
        escape(query_s)
      end

      # Check if a Hash key from a search keys structure format is correct.
      #
      # @param k [Mixed] hash key to check.
      # @return [Boolean] `true` if key is a `String` or a `Symbol`.
      # @api private
      def valid_search_keys_key?(k)
        k.is_a?(String) || k.is_a?(Symbol)
      end

      # Check if a Hash value from a search keys structure format is correct.
      #
      # @param v [Mixed] hash value to check.
      # @return [Boolean] `true` if value is a `Array<String>`.
      # @api private
      def valid_search_keys_value?(v)
        return false unless v.is_a?(Array)
        v.reduce(true) { |a, e| a && e.is_a?(String) }
      end

      # Check if a search keys structure format is correct.
      #
      # This is an example of a correct search structure:
      #
      # ```ruby
      # {
      #   ipaddress: %w(ipaddress),
      #   mysql_version: %w(mysql version)
      # }
      # ```
      #
      # @param keys [Hash] search keys structure.
      # @return [Boolean] `true` if search keys structure format is correct.
      # @api private
      def valid_search_keys?(keys)
        return false unless keys.is_a?(Hash)
        keys.reduce(true) do |r, (k, v)|
          r && valid_search_keys_key?(k) && valid_search_keys_value?(v)
        end
      end

      # Assert that the search keys structure format is correct.
      #
      # @raise [InvalidSearchKeys] if search keys structure is wrong.
      # @return void
      # @api private
      def assert_search_keys(keys)
        return if valid_search_keys?(keys)
        fail InvalidSearchKeys, "Invalid search keys: #{keys.inspect}"
      end

      # Check if search query is empty.
      #
      # @param query [Array<String>, String] search query.
      # @return [Boolean] `true` if search query is empty.
      # @api private
      def empty_search?(query)
        query.is_a?(String) && query.empty? ||
          query.is_a?(Array) && query.count == 0
      end


      # Does a search in the Chef Server.
      #
      # @param type [Symbol] search index to use. See [Chef Search Indexes]
      #   (http://docs.getchef.com/chef_search.html#search-indexes).
      # @param query [Array<String>, String] search query. For example:
      #   `%w(admin:true)`. Results will be *OR*-ed when multiple string queries
      #   are provided.
      # @param keys [Hash] search keys structure. For example:
      #   `{ipaddress: %w(ipaddress), mysql_version: %w(mysql version) }`.
      # @param rows [Fixnum, String] maximum number of rows to return.
      # @param partial_search [Boolean] whethet to use partial search.
      # @raise [SearchFailure] if there is a search error.
      def search(type, query, keys, rows = 1000, partial_search = true)
        return [] if empty_search?(query) # avoid empty searches
        search_method = partial_search ? :partial_search : :normal_search
        send(search_method, type, query, keys, rows)
      rescue Net::HTTPServerException => e
        unless e.response.is_a?(Net::HTTPResponse) && e.response.code == '404'
          raise SearchFailure, "Search exception #{e.class}: #{e}"
        end
        return []
      rescue Net::HTTPFatalError => e
        raise SearchFailure, "Search exception #{e.class}: #{e}"
      end

      # Assert that the normal (no partial) search response is correct.
      #
      # @param resp [Array] normal search result.
      # @return void
      # @raise [SearchFatalError] if the search response is wrong.
      # @api private
      def assert_normal_search_response(resp)
        return if resp.is_a?(Array)
        fail SearchFatalError,
             "Wrong response received from Normal Search: #{resp.inspect}"
      end

      # Parses a normal (no partial) search response row.
      #
      # @param row [Array] the normal search result row.
      # @param attr_ary [Array<String>] key path as Array.
      # @api private
      def parse_normal_search_row_attribute(row, attr_ary)
        attr_ary.reduce(row) do |r, attr|
          if r.respond_to?(attr)
            r.send(attr)
          elsif r.respond_to?(:key?)
            r[attr.to_s] if r.key?(attr.to_s)
          end
        end
      end

      # Parses a normal (no partial) full search search response.
      #
      # @param resp [Array] normal search result.
      # @param keys [Hash] search keys structure. For example:
      #   `{ipaddress: %w(ipaddress), mysql_version: %w(mysql version) }`.
      # @api private
      def parse_normal_search_response(resp, keys)
        resp.map do |row|
          Hash[keys.map do |key_name, attr_ary|
            value = parse_normal_search_row_attribute(row, attr_ary)
            [key_name, value]
          end]
        end
      end

      # Does a normal (no partial) search in the Chef Server.
      #
      # @param type [Symbol] search index to use. See [Chef Search Indexes]
      #   (http://docs.getchef.com/chef_search.html#search-indexes).
      # @param query [String, Array<String>] search query. For example:
      #   `%w(admin:true)`. Results will be *OR*-ed when multiple string queries
      #   are provided.
      # @param keys [Hash] search keys structure. For example:
      #   `{ipaddress: %w(ipaddress), mysql_version: %w(mysql version) }`.
      # @param rows [Fixnum, String] maximum number of rows to return.
      def normal_search(type, query, keys, rows = 1000)
        escaped_query = escape_query(query)
        Chef::Log.info(
          "Normal Search query: #{escaped_query}, keys: #{keys.inspect}"
        )
        assert_search_keys(keys)

        resp = self.query.search(type, escaped_query, nil, 0, rows)[0]
        assert_normal_search_response(resp)
        parse_normal_search_response(resp, keys)
      end

      # Assert that the partial search response is correct.
      #
      # @param resp [Hash] partial search result. For example:
      #   `{ 'rows' => [ 'data' => { 'ipaddress' => '192.168.1.1' } }] }`.
      # @return void
      # @raise [SearchFatalError] if the search response is wrong.
      # @api private
      def assert_partial_search_response(resp)
        return if resp.is_a?(Hash) && resp.key?('rows') &&
                  resp['rows'].is_a?(Array)
        fail SearchFatalError,
             "Wrong response received from Partial Search: #{resp.inspect}"
      end

      # Parses a partial full search search response.
      #
      # @param resp [Hash] partial search result. For example:
      #   `{ 'rows' => [ 'data' => { 'ipaddress' => '192.168.1.1' } }] }`.
      # @raise [SearchFatalError] if the search response is wrong.
      # @api private
      def parse_partial_search_response(resp)
        resp['rows'].map do |row|
          if row.is_a?(Hash) && row['data'].is_a?(Hash)
            row['data']
          else
            fail SearchFatalError,
                 "Wrong row format received from Partial Search: #{row.inspect}"
          end
        end.compact
      end

      # Does a partial search in the Chef Server.
      #
      # @param type [Symbol] search index to use. See [Chef Search Indexes]
      #   (http://docs.getchef.com/chef_search.html#search-indexes).
      # @param query [String, Array<String>] search query. For example:
      #   `%w(admin:true)`. Results will be *OR*-ed when multiple string queries
      #   are provided.
      # @param keys [Hash] search keys structure. For example:
      #   `{ipaddress: %w(ipaddress), mysql_version: %w(mysql version) }`.
      # @param rows [Fixnum, String] maximum number of rows to return.
      def partial_search(type, query, keys, rows = 1000)
        escaped_query =
          "search/#{escape(type)}?q=#{escape_query(query)}&start=0&rows=#{rows}"
        Chef::Log.info(
          "Partial Search query: #{escaped_query}, keys: #{keys.inspect}"
        )
        assert_search_keys(keys)

        rest = Chef::REST.new(Chef::Config[:chef_server_url])
        resp = rest.post_rest(escaped_query, keys)
        assert_partial_search_response(resp)
        parse_partial_search_response(resp)
      end
    end
  end
end
