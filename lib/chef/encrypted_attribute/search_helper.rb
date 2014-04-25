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
    module SearchHelper
      extend self

      def query
        Chef::Search::Query.new
      end

      def escape(str)
        URI.escape(str.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end

      def escape_query(query)
        query_s = if query.kind_of?(Array)
          query.map do |item|
            "( #{item} )"
          end.compact.join(' OR ')
        else
          query.to_s
        end
        escape(query_s)
      end

      def valid_search_keys?(keys)
        return false unless keys.kind_of?(Hash)
        keys.reduce(true) do |r, (k, v)|
          r && unless k.kind_of?(String) || k.kind_of?(Symbol) and v.kind_of?(Array)
            false
          else
            v.reduce(true) do |r, x|
              r and x.kind_of?(String)
            end
          end
        end
      end

      def empty_search?(query)
        query.kind_of?(String) && query.empty? or
        query.kind_of?(Array) && query.count == 0
      end

      def search(type, query, keys, rows=1000, partial_search=true)
        return [] if empty_search?(query) # avoid empty searches
        if partial_search
          partial_search(type, query, keys, rows)
        else
          normal_search(type, query, keys, rows)
        end
      end

      def normal_search(type, query, keys, rows=1000)
        escaped_query = escape_query(query)
        Chef::Log.info("Normal Search query: #{escaped_query}, keys: #{keys.inspect}")
        unless valid_search_keys?(keys)
          raise InvalidSearchKeys, "Invalid search keys: #{keys.inspect}"
        end

        begin
          resp = self.query.search(type, escaped_query, nil, 0, rows)[0]
        rescue Net::HTTPServerException => e
          if e.response.kind_of?(Net::HTTPResponse) and e.response.code == '404' # Not Found
            return []
          else
            raise SearchFailure, "Partial Search exception #{e.class.name}: #{e.to_s}"
          end
        rescue Net::HTTPFatalError => e
          raise SearchFailure, "Normal Search exception #{e.class.name}: #{e.to_s}"
        end
        unless resp.kind_of?(Array)
          raise SearchFatalError, "Wrong response received from Normal Search: #{resp.inspect}"
        end
        # TODO too complex, refactorize
        resp.map do |row|
          Hash[keys.map do |key_name, attr_ary|
            value = attr_ary.reduce(row) do |r, attr|
              if r.respond_to?(attr.to_sym)
                r.send(attr.to_sym)
              elsif r.respond_to?(:has_key?)
                if r.has_key?(attr.to_s)
                  r[attr.to_s]
                end
              end
            end
            [ key_name, value ]
          end]
        end
      end

      def partial_search(type, query, keys, rows=1000)
        escaped_query = "search/#{escape(type)}?q=#{escape_query(query)}&start=0&rows=#{rows}"
        Chef::Log.info("Partial Search query: #{escaped_query}, keys: #{keys.inspect}")
        unless valid_search_keys?(keys)
          raise InvalidSearchKeys, "Invalid search keys: #{keys.inspect}"
        end

        rest = Chef::REST.new(Chef::Config[:chef_server_url])
        begin
          resp = rest.post_rest(escaped_query, keys)
        rescue Net::HTTPServerException => e
          if e.response.kind_of?(Net::HTTPResponse) and e.response.code == '404' # Not Found
            return []
          else
            raise SearchFailure, "Partial Search exception #{e.class.name}: #{e.to_s}"
          end
        rescue Net::HTTPFatalError => e
          raise SearchFailure, "Partial Search exception #{e.class.name}: #{e.to_s}"
        end
        unless resp.kind_of?(Hash) and resp.has_key?('rows') and resp['rows'].kind_of?(Array)
          raise SearchFatalError, "Wrong response received from Partial Search: #{resp.inspect}"
        end
        resp['rows'].map do |row|
          if row.kind_of?(Hash) and row['data'].kind_of?(Hash)
            row['data']
          else
            raise SearchFatalError, "Wrong row format received from Partial Search: #{row.inspect}"
          end
        end.compact
      end

    end
  end
end
