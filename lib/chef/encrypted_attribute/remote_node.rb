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

require 'chef/mixin/params_validate'
require 'chef/encrypted_attribute/search_helper'
require 'chef/encrypted_attribute/cache_lru'

class Chef
  class EncryptedAttribute
    # Remote Node object to read and save its attributes
    class RemoteNode
      include ::Chef::Mixin::ParamsValidate
      include ::Chef::EncryptedAttribute::SearchHelper

      def initialize(name)
        name(name)
      end

      def self.cache
        # disabled by default
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new(0)
      end

      def name(arg = nil)
        set_or_return(
          :name,
          arg,
          kind_of: String
        )
      end

      def load_attribute(attr_ary, partial_search = true)
        assert_attribute_array(attr_ary)
        cache_key = cache_key(name, attr_ary)
        return self.class.cache[cache_key] if self.class.cache.key?(cache_key)
        keys = { 'value' => attr_ary }
        res = search(:node, "name:#{@name}", keys, 1, partial_search)
        self.class.cache[cache_key] =
          if res.is_a?(Array) && res[0].is_a?(Hash) && res[0].key?('value')
            res[0]['value']
          else
            nil
          end
      end

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

      def cache_key(name, attr_ary)
        "#{name}:#{attr_ary.inspect}" # TODO: ok, this can be improved
      end

      def assert_attribute_array(attr_ary)
        return if attr_ary.is_a?(Array)
        fail ArgumentError,
             "#{self.class}##{__method__} attr_ary argument must be an array "\
             "of strings. You passed #{attr_ary.inspect}."
      end
    end
  end
end
