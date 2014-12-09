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

require 'chef/api_client'

require 'chef/encrypted_attribute/exceptions'
require 'chef/encrypted_attribute/search_helper'
require 'chef/encrypted_attribute/cache_lru'

class Chef
  class EncryptedAttribute
    # Search remote Chef Clients public keys.
    class RemoteClients
      extend ::Chef::EncryptedAttribute::SearchHelper

      # Remote clients search results cache.
      #
      # You can disable it setting it's size to zero:
      #
      # ```ruby
      # Chef::EncryptedAttribute::RemoteClients.cache.max_size(0)
      # ```
      #
      # @return [CacheLru] Remote clients LRU cache.
      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new
      end

      # Gets remote client public key.
      #
      # @param name [String] Chef client name.
      # @return [String] Chef client public key as string.
      # @raise ClientNotFound if client does not exist.
      # @raise Net::HTTPServerException for HTTP errors.
      def self.get_public_key(name)
        Chef::ApiClient.load(name).public_key
      rescue Net::HTTPServerException => e
        raise e unless e.response.code == '404'
        raise ClientNotFound, "Chef Client not found: #{name.inspect}."
      end

      # Search for chef client public keys.
      #
      # @param search [Array<String>, String] search queries to perform, the
      #   query result will be *OR*-ed.
      # @return [Array<String>] list of public keys.
      def self.search_public_keys(search = '*:*', partial_search = true)
        escaped_query = escape_query(search)
        return cache[escaped_query] if cache.key?(escaped_query)
        cache[escaped_query] = search(
          :client, search,
          { 'public_key' => %w(public_key) }, 1000, partial_search
        ).map { |client| client['public_key'] }.compact
      end
    end
  end
end
