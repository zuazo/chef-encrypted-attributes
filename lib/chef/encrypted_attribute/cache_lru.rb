# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
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

class Chef
  class EncryptedAttribute
    # Implements an LRU (Least Recently Used) cache object.
    #
    # The LRU cache algorithm discards the least recently used items first.
    #
    # This class extends from *Hash* class and adds methods to behave as a
    # cache.
    #
    # You can use the `clear` class method to clean a cache:
    #
    # ```ruby
    # Chef::EncryptedAttribute::RemoteClients.cache.clear
    # Chef::EncryptedAttribute::RemoteNodes.cache.clear
    # Chef::EncryptedAttribute::RemoteUsers.cache.clear
    # Chef::EncryptedAttribute::RemoteNode.cache.clear
    # ```
    #
    # @note Based on [SamSaffron](https://github.com/SamSaffron) work:
    #   https://github.com/SamSaffron/lru_redux
    # @see API
    class CacheLru < Hash
      include ::Chef::Mixin::ParamsValidate

      # Constructs a new Cache LRU object.
      #
      # @param size [Fixnum] Cache maximum size in object count.
      def initialize(size = nil)
        super
        max_size(size)
      end

      # Reads or sets the cache maximum size.
      #
      # Removes some values if needed (when the size is reduced).
      #
      # The cache size is `1024` by default.
      #
      # @param arg [Fixnum] cache maximum size to set.
      # @return [Fixnum] cache maximum size.
      def max_size(arg = nil)
        set_or_return(
          :max_size,
          arg,
          kind_of: [Fixnum], default: 1024,
          callbacks: { 'should not be lower that zero' => ->(x) { x >= 0 } }
        )
        pop_tail unless arg.nil?
        @max_size
      end

      # Reads a cache key.
      #
      # @param key [String, Symbol] cache key to read.
      # @return [Mixed] cache key value.
      def [](key)
        return nil unless key?(key)
        val = super(key)
        self[key] = val
      end

      # Sets a cache key.
      #
      # Some keys will be removed if the cache size grows too much. The keys to
      # be removed will be chosen using the LRU algorithm.
      #
      # @param key [String, Symbol] cache key to set.
      # @param val [Mixed] cache key value.
      # @return [Mixed] cache key value.
      def []=(key, val)
        if max_size > 0 # unnecessary "if", small optimization?
          delete(key)
          super(key, val)
          pop_tail
        end
        val
      end

      protected

      # Removes the tail elements until the size is correct.
      #
      # This method is needed to implement the LRU algorithm.
      #
      # @return void
      def pop_tail
        delete(first[0]) while size > max_size
      end
    end
  end
end
