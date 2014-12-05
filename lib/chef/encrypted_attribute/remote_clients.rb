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
    # Search remote Chef Clients public search
    class RemoteClients
      extend ::Chef::EncryptedAttribute::SearchHelper

      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new
      end

      def self.get_public_key(name)
        Chef::ApiClient.load(name).public_key
      rescue Net::HTTPServerException => e
        raise e unless e.response.code == '404'
        raise ClientNotFound, "Chef Client not found: #{name.inspect}."
      end

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
