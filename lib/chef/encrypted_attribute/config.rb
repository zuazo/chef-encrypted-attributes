#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
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
    class Config
      include ::Chef::Mixin::ParamsValidate

      def initialize(config={})
        config.each do |key, value|
          if Chef::EncryptedAttribute::Config.method_defined?(key) and
             not /^config_/ =~ key.to_s
            self.send(key, value)
          else
            Chef::Log.warn("#{self.class.to_s}: configuration method not found: #{key}.")
          end
        end
      end

      def version(arg=nil)
        unless arg.nil? or not arg.kind_of?(String)
          arg = Integer(arg) rescue arg
        end
        set_or_return(
          :version,
          arg,
          :kind_of => [ Fixnum, String ],
          :default => 0
        )
      end

      def partial_search(arg=nil)
        set_or_return(
          :partial_search,
          arg,
          :kind_of => [ TrueClass, FalseClass ],
          :default => true
        )
      end

      def client_search(arg=nil)
        unless arg.nil? or not arg.kind_of?(String)
          arg = [ arg ]
        end
        set_or_return(
          :client_search,
          arg,
          :kind_of => Array,
          :default => [ 'admin:true' ],
          # TODO check if this is supported in old Chef versions
          :callbacks => config_search_array_callbacks
        )
      end

      # TODO change this to array of keys?
      def keys(arg=nil)
        set_or_return(
          :keys,
          arg,
          :kind_of => Hash,
          :default => {},
          # TODO check if this is supported in old Chef versions
          :callbacks => config_valid_keys_hash_callbacks
        )
      end

      def key_add(name, key)
        if name.kind_of?(String) and key.kind_of?(String)
          @keys[name] = key
        end
      end

      protected

      def config_valid_search_array?(s_ary)
        s_ary.each do |s|
          # TODO a less generic check?
          return false unless s.kind_of?(String)
        end
        true
      end

      def config_search_array_callbacks
        {
          'should be a valid array of search patterns' => lambda do |cs|
            config_valid_search_array?(cs)
          end
        }
      end

      def config_valid_keys_hash?(k_hs)
        k_hs.each do |k, v|
          unless k.kind_of?(String) and v.kind_of?(String)
            return false
          end
        end
        true
      end

      def config_valid_keys_hash_callbacks
        {
          'should be a valid hash of keys' => lambda do |keys|
            config_valid_keys_hash?(keys)
          end
        }
      end

    end
  end
end
