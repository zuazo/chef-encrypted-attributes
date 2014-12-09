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

require 'chef/encrypted_attribute/exceptions'
require 'chef/encrypted_attribute/search_helper'
require 'chef/encrypted_attribute/cache_lru'
require 'chef/encrypted_attribute/remote_clients'

class Chef
  class EncryptedAttribute
    # Helpers to search nodes remotely and get it's public keys.
    class RemoteNodes
      extend ::Chef::EncryptedAttribute::SearchHelper

      # Remote nodes search results cache.
      #
      # You can disable it setting it's size to zero:
      #
      # ```ruby
      # Chef::EncryptedAttribute::RemoteNodes.cache.max_size(0)
      # ```
      #
      # @return [CacheLru] Remote nodes LRU cache.
      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new
      end

      # Gets remote node public key.
      #
      # It first tries to read the key from the `node['public_key']` attribute.
      #
      # If the `"public_key"` attribute does not exist, it tries to read the
      # node client key directly using the Chef API (this require **admin**
      # privileges).
      #
      # @param node [Chef::Node] Chef node object.
      # @return [String] Chef client public key as string.
      # @raise InsufficientPrivileges if you lack enoght privileges.
      # @raise Net::HTTPServerException for HTTP errors.
      def self.get_public_key(node)
        return node['public_key'] unless node['public_key'].nil?
        RemoteClients.get_public_key(node['name'])
      rescue Net::HTTPServerException => e
        raise e unless e.response.code == '403'
        raise InsufficientPrivileges,
              "You cannot read #{node['name']} client key. Consider including "\
              'the encrypted_attributes::expose_key recipe in the '\
              "#{node['name']} node run list."
      end

      # Searches for node client public keys.
      #
      # It first tries to read the key from the `node['public_key']` attribute.
      #
      # If the `"public_key"` attribute does not exist, it tries to read the
      # node client key directly using the Chef API (this require **admin**
      # privileges).
      #
      # @param search [Array<String>, String] search queries to perform, the
      #   query result will be *OR*-ed.
      # @return [Array<String>] list of public keys.
      # @raise InsufficientPrivileges if you lack enoght privileges.
      # @raise Net::HTTPServerException for HTTP errors.
      def self.search_public_keys(search = '*:*', partial_search = true)
        escaped_query = escape_query(search)
        return cache[escaped_query] if cache.key?(escaped_query)
        cache[escaped_query] =
          search(
            :node, search,
            { 'name' => %w(name), 'public_key' => %w(public_key) },
            1000, partial_search
          ).map { |node| get_public_key(node) }.compact
      end
    end
  end
end
