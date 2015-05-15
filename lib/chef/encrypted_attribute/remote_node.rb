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

require 'chef/mixin/params_validate'
require 'chef/encrypted_attribute/search_helper'
require 'chef/encrypted_attribute/cache_lru'

class Chef
  class EncryptedAttribute
    # Remote Node object to read and save node attributes remotely.
    class RemoteNode
      include ::Chef::Mixin::ParamsValidate
      include ::Chef::EncryptedAttribute::SearchHelper

      # Remote Node object constructor.
      #
      # @param name [String] node name.
      def initialize(name)
        name(name)
      end

      # Remote node attribute values cache.
      #
      # It is disabled by default. You can enable it changing it's size:
      #
      # ```ruby
      # Chef::EncryptedAttribute::RemoteNode.cache.max_size(1024)
      # ```
      #
      # @return [CacheLru] node attributes LRU cache.
      def self.cache
        # disabled by default
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new(0)
      end

      # Read or set node name.
      #
      # @param arg [String] node name.
      # @return [String] node name.
      def name(arg = nil)
        # TODO: clean the cache when changed?
        set_or_return(
          :name,
          arg,
          kind_of: String
        )
      end

      # Loads a remote node attribute.
      #
      # @param attr_ary [Array<String>] node attribute path as Array.
      # @param partial_search [Boolean] whether to use partial search.
      # @return [Mixed] node attribute value, `nil` if not found.
      # @raise [ArgumentError] if the attribute path format is wrong.
      # @raise [SearchFailure] if there is a Chef search error.
      # @raise [SearchFatalError] if the Chef search response is wrong.
      # @raise [InvalidSearchKeys] if search keys structure is wrong.
      def load_attribute(attr_ary, partial_search = true)
        assert_attribute_array(attr_ary)
        cache_key = cache_key(name, attr_ary)
        return self.class.cache[cache_key] if self.class.cache.key?(cache_key)
        keys = { 'value' => attr_ary }
        res = search_by_name(:node, @name, keys, 1, partial_search)
        self.class.cache[cache_key] = parse_search_result(res)
      end

      # Saves a remote node attribute.
      #
      # @param attr_ary [Array<String>] node attribute path as Array.
      # @param value [Mixed] node attribute value to set.
      # @return [Mixed] node attribute value.
      # @raise [ArgumentError] if the attribute path format is wrong.
      def save_attribute(attr_ary, value)
        assert_attribute_array(attr_ary)
        cache_key = cache_key(name, attr_ary)

        node = Chef::Node.load(name)
        last = attr_ary.pop
        node_attr = attr_ary.reduce(node.normal) do |a, k|
          a[k] = Mash.new unless a.key?(k)
          a[k]
        end
        node_attr[last] = value

        node.save
        self.class.cache[cache_key] = value
      end

      # Deletes a remote node attribute.
      #
      # @param attr_ary [Array<String>] node attribute path as Array.
      # @return [Boolean] whether the node attribute has been found and
      #   successfully deleted.
      # @raise [ArgumentError] if the attribute path format is wrong.
      def delete_attribute(attr_ary)
        assert_attribute_array(attr_ary)
        cache_key = cache_key(name, attr_ary)

        node = Chef::Node.load(name)
        last = attr_ary.pop
        node_attr = attr_ary.reduce(node.normal) do |a, k|
          a.respond_to?(:key?) && a.key?(k) ? a[k] : nil
        end
        if node_attr.respond_to?(:key?) && node_attr.key?(last)
          node_attr.delete(last)
          node.save
          self.class.cache.delete(cache_key)
          true
        else
          false
        end
      end

      protected

      # Parses {SearchHelper#search} result.
      #
      # @param res [Array<Hash>] {SearchHelper#search} result.
      # @return [Mixed] final search result value.
      def parse_search_result(res)
        unless res.is_a?(Array) && res[0].is_a?(Hash) && res[0].key?('value')
          return nil
        end
        res[0]['value']
      end

      # Generates the cache key.
      #
      # @param name [String] node name.
      # @param attr_ary [Array<String>] node attribute path as Array.
      # @return [String] cache key.
      def cache_key(name, attr_ary)
        "#{name}:#{attr_ary.inspect}" # TODO: OK, this can be improved
      end

      # Asserts that the attribute path is in the correct format.
      #
      # @param attr_ary [Array<String>] node attribute path as Array.
      # @return void
      # @raise [ArgumentError] if the attribute path format is wrong.
      def assert_attribute_array(attr_ary)
        return if attr_ary.is_a?(Array)
        fail ArgumentError,
             "#{self.class}##{__method__} attr_ary argument must be an array "\
             "of strings. You passed #{attr_ary.inspect}."
      end
    end
  end
end
