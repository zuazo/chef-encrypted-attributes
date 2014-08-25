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
    class RemoteNodes
      extend ::Chef::EncryptedAttribute::SearchHelper

      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new
      end

      def self.search_public_keys(search='*:*', partial_search=true)
        escaped_query = escape_query(search)
        if cache.has_key?(escaped_query)
          cache[escaped_query]
        else
          cache[escaped_query] = search(:node, search, {
            'name' => [ 'name' ]
          }, 1000, partial_search).map do |node|
            RemoteClients.get_public_key(node['name'])
          end.compact
        end
      end

    end
  end
end
