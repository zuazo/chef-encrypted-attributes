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
    # Search Helpers to do normal or partial searches
    module SearchHelper
      extend self

      def query
        Chef::Search::Query.new
      end

      def escape(str)
        URI.escape(str.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end

      def escape_query(query)
        query_s =
          if query.is_a?(Array)
            query.map { |item| "( #{item} )" }.compact.join(' OR ')
          else
            query.to_s
          end
        escape(query_s)
      end

      def valid_search_keys?(keys)
        return false unless keys.is_a?(Hash)
        keys.reduce(true) do |r, (k, v)|
          r && if (k.is_a?(String) || k.is_a?(Symbol)) && v.is_a?(Array)
                 v.reduce(true) { |a, e| a && e.is_a?(String) }
               else
                 false
               end
        end
      end

      def empty_search?(query)
        query.is_a?(String) && query.empty? ||
          query.is_a?(Array) && query.count == 0
      end

      def search(type, query, keys, rows = 1000, partial_search = true)
        return [] if empty_search?(query) # avoid empty searches
        if partial_search
          partial_search(type, query, keys, rows)
        else
          normal_search(type, query, keys, rows)
        end
      end

      def normal_search(type, query, keys, rows = 1000)
        escaped_query = escape_query(query)
        Chef::Log.info(
          "Normal Search query: #{escaped_query}, keys: #{keys.inspect}"
        )
        unless valid_search_keys?(keys)
          fail InvalidSearchKeys, "Invalid search keys: #{keys.inspect}"
        end

        begin
          resp = self.query.search(type, escaped_query, nil, 0, rows)[0]
        rescue Net::HTTPServerException => e
          if e.response.is_a?(Net::HTTPResponse) && e.response.code == '404'
            return []
          else
            raise SearchFailure, "Partial Search exception #{e.class}: #{e}"
          end
        rescue Net::HTTPFatalError => e
          raise SearchFailure, "Normal Search exception #{e.class}: #{e}"
        end
        unless resp.is_a?(Array)
          fail SearchFatalError,
               "Wrong response received from Normal Search: #{resp.inspect}"
        end
        # TODO: too complex, refactorize
        resp.map do |row|
          Hash[keys.map do |key_name, attr_ary|
            value = attr_ary.reduce(row) do |r, attr|
              if r.respond_to?(attr.to_sym)
                r.send(attr.to_sym)
              elsif r.respond_to?(:key?)
                r[attr.to_s] if r.key?(attr.to_s)
              end
            end
            [key_name, value]
          end]
        end
      end

      def partial_search(type, query, keys, rows = 1000)
        escaped_query =
          "search/#{escape(type)}?q=#{escape_query(query)}&start=0&rows=#{rows}"
        Chef::Log.info(
          "Partial Search query: #{escaped_query}, keys: #{keys.inspect}"
        )
        unless valid_search_keys?(keys)
          fail InvalidSearchKeys, "Invalid search keys: #{keys.inspect}"
        end

        rest = Chef::REST.new(Chef::Config[:chef_server_url])
        begin
          resp = rest.post_rest(escaped_query, keys)
        rescue Net::HTTPServerException => e
          if e.response.is_a?(Net::HTTPResponse) && e.response.code == '404'
            return []
          else
            raise SearchFailure, "Partial Search exception #{e.class}: #{e}"
          end
        rescue Net::HTTPFatalError => e
          raise SearchFailure, "Partial Search exception #{e.class}: #{e}"
        end
        unless resp.is_a?(Hash) && resp.key?('rows') &&
               resp['rows'].is_a?(Array)
          fail SearchFatalError,
               "Wrong response received from Partial Search: #{resp.inspect}"
        end
        resp['rows'].map do |row|
          if row.is_a?(Hash) && row['data'].is_a?(Hash)
            row['data']
          else
            fail SearchFatalError,
                 "Wrong row format received from Partial Search: #{row.inspect}"
          end
        end.compact
      end
    end
  end
end
