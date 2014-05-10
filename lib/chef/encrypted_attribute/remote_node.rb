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
    class RemoteNode
      include ::Chef::Mixin::ParamsValidate
      include ::Chef::EncryptedAttribute::SearchHelper

      def initialize(name)
        name(name)
      end

      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new(0) # disabled by default
      end

      def name(arg=nil)
        set_or_return(
          :name,
          arg,
          :kind_of => String
        )
      end

      def load_attribute(attr_ary, partial_search=true)
        unless attr_ary.kind_of?(Array)
          raise ArgumentError, "#{self.class.to_s}##{__method__} attr_ary argument must be an array of strings. You passed #{attr_ary.inspect}."
        end
        cache_key = cache_key(name, attr_ary)
        if self.class.cache.has_key?(cache_key)
          self.class.cache[cache_key]
        else
          keys = { 'value' => attr_ary }
          res = search(:node, "name:#{@name}", keys, 1, partial_search)
          self.class.cache[cache_key] = if res.kind_of?(Array) and
               res[0].kind_of?(Hash) and res[0].has_key?('value')
              res[0]['value']
            else
              nil
            end
        end
      end

      def save_attribute(attr_ary, value)
        unless attr_ary.kind_of?(Array)
          raise ArgumentError, "#{self.class.to_s}##{__method__} attr_ary argument must be an array of strings. You passed #{attr_ary.inspect}."
        end
        cache_key = cache_key(name, attr_ary)

        node = Chef::Node.load(name)
        last = attr_ary.pop
        node_attr = attr_ary.reduce(node.normal) do |a, k|
          a[k] = Mash.new unless a.has_key?(k)
          a[k]
        end
        node_attr[last] = value

        node.save
        self.class.cache[cache_key] = value
      end

      def delete_attribute(attr_ary)
        unless attr_ary.kind_of?(Array)
          raise ArgumentError, "#{self.class.to_s}##{__method__} attr_ary argument must be an array of strings. You passed #{attr_ary.inspect}."
        end
        cache_key = cache_key(name, attr_ary)

        node = Chef::Node.load(name)
        last = attr_ary.pop
        node_attr = attr_ary.reduce(node.normal) do |a, k|
          a.respond_to?(:has_key?) && a.has_key?(k) ? a[k] : nil
        end
        if node_attr.respond_to?(:has_key?) && node_attr.has_key?(last)
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
        "#{name}:#{attr_ary.inspect}" # TODO ok, this can be improved
      end

    end
  end
end
