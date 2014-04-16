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

class Chef
  class EncryptedAttribute
    module SearchHelper

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

      def search(type, query, keys, rows=1000)
        if Chef::EncryptedAttribute.config.partial_search
          partial_search(type, query, keys, rows)
        else
          normal_search(type, query, keys, rows)
        end
      end

      def normal_search(type, query, keys, rows=1000)
        resp = self.query.search(type, escape_query(query), nil, 0, rows)[0]
        # TODO too complex, refactorize
        resp.map do |row|
          Hash[keys.map do |key_name, attr_ary|
            value = attr_ary.reduce(row) do |r, attr|
              if r.respond_to?(attr.to_sym)
                r.send(attr.to_sym)
              elsif r.respond_to?(:has_key?) and
                r.has_key?(attr)
                r[attr]
              end
            end
            [ key_name, value ]
          end]
        end
      end

      def partial_search(type, query, keys, rows=1000)
        escaped_query = "search/#{escape(type)}?q=#{escape_query(query)}&start=0&rows=#{rows}"
        Chef::Log.info("Partial search query: #{escaped_query}")
        Chef::Log.info("Partial search keys: #{keys.inspect}")
        rest = Chef::REST.new(Chef::Config[:chef_server_url])
        resp = rest.post_rest(escaped_query, keys)
        if resp['rows'].kind_of?(Array)
          resp['rows'].map do |row|
            if row.kind_of?(Hash) and row['data'].kind_of?(Hash)
              row['data']
            end
          end.compact
        else
          Chef::Log.warn('Wrong result from partial search.')
          []
        end
      end

    end
  end
end
