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

class Chef
  class EncryptedAttribute
    class Config
      include ::Chef::Mixin::ParamsValidate

      OPTIONS = [
        :version,
        :partial_search,
        :client_search,
        :users,
        :keys,
      ].freeze

      def initialize(config=nil)
        update!(config) unless config.nil?
      end

      def version(arg=nil)
        unless arg.nil? or not arg.kind_of?(String)
          arg = Integer(arg) rescue arg
        end
        set_or_return(
          :version,
          arg,
          :kind_of => [ Fixnum, String ],
          :default => 1
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
          :default => [],
          :callbacks => config_search_array_callbacks
        )
      end

      def users(arg=nil)
        set_or_return(
          :users,
          arg,
          :kind_of => [ String, Array ],
          :default => [],
          :callbacks => config_users_arg_callbacks
        )
      end

      def keys(arg=nil)
        set_or_return(
          :keys,
          arg,
          :kind_of => Array,
          :default => [],
          :callbacks => config_valid_keys_array_callbacks
        )
      end

      def update!(config)
        if config.kind_of?(self.class)
          OPTIONS.each do |attr|
            value = dup_object(config.send(attr))
            self.instance_variable_set("@#{attr.to_s}", value)
          end
        elsif config.kind_of?(Hash)
          config.each do |attr, value|
            attr = attr.to_sym if attr.kind_of?(String)
            if OPTIONS.include?(attr)
              value = dup_object(value)
              self.send(attr, value)
            else
              Chef::Log.warn("#{self.class.to_s}: configuration method not found: \"#{attr.to_s}\".")
            end
          end
        end
      end

      def [](key)
        key = key.to_sym if key.kind_of?(String)
        if OPTIONS.include?(key)
          self.send(key)
        end
      end

      def []=(key, value)
        key = key.to_sym if key.kind_of?(String)
        if OPTIONS.include?(key)
          self.send(key, value)
        end
      end

      protected

      def dup_object(o)
        o.dup
      rescue TypeError
        o
      end

      def config_valid_search_array?(s_ary)
        s_ary.each do |s|
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

      def config_valid_user_arg?(users)
        return users == '*' if users.kind_of?(String)
        users.each do |u|
          return false unless u.kind_of?(String) and u.match(/^[a-z0-9\-_]+$/)
        end
        true
      end

      def config_users_arg_callbacks
        {
          'should be a valid array of search patterns' => lambda do |us|
            config_valid_user_arg?(us)
          end
        }
      end

      def config_valid_key?(k)
        rsa_k = case k
        when OpenSSL::PKey::RSA
          k
        when String
          begin
            OpenSSL::PKey::RSA.new(k)
          rescue OpenSSL::PKey::RSAError, TypeError
            nil
          end
        else
          nil
        end
        return false if rsa_k.nil?
        rsa_k.public?
      end

      def config_valid_keys_array?(k_ary)
        k_ary.each do |k|
          unless config_valid_key?(k)
            return false
          end
        end
        true
      end

      def config_valid_keys_array_callbacks
        {
          'should be a valid array of keys' => lambda do |keys|
            config_valid_keys_array?(keys)
          end
        }
      end

    end
  end
end