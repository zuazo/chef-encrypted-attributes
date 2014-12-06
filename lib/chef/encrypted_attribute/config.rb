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
    # Sets and reads encrypted attributes configuration options
    class Config
      include ::Chef::Mixin::ParamsValidate

      OPTIONS = [
        :version,
        :partial_search,
        :client_search,
        :node_search,
        :users,
        :keys
      ].freeze

      def initialize(config = nil)
        update!(config) unless config.nil?
      end

      def version(arg = nil)
        unless arg.nil? || !arg.is_a?(String)
          begin
            arg = Integer(arg)
          rescue ArgumentError
            arg
          end
        end
        set_or_return(:version, arg, kind_of: [Fixnum, String], default: 1)
      end

      def partial_search(arg = nil)
        set_or_return(
          :partial_search, arg, kind_of: [TrueClass, FalseClass], default: true
        )
      end

      def client_search(arg = nil)
        set_or_return_search_array(:client_search, arg)
      end

      def node_search(arg = nil)
        set_or_return_search_array(:node_search, arg)
      end

      def users(arg = nil)
        set_or_return(
          :users, arg,
          kind_of: [String, Array], default: [],
          callbacks: config_users_arg_callbacks
        )
      end

      def keys(arg = nil)
        set_or_return(
          :keys, arg,
          kind_of: Array, default: [],
          callbacks: config_valid_keys_array_callbacks
        )
      end

      def update!(config)
        if config.is_a?(self.class)
          update_from_config!(config)
        elsif config.is_a?(Hash)
          update_from_hash!(config)
        end
      end

      def [](key)
        key = key.to_sym if key.is_a?(String)
        send(key) if OPTIONS.include?(key)
      end

      def []=(key, value)
        key = key.to_sym if key.is_a?(String)
        send(key, value) if OPTIONS.include?(key)
      end

      protected

      def dup_object(o)
        o.dup
      rescue TypeError
        o
      end

      def set_or_return_search_array(name, arg = nil)
        arg = [arg] unless arg.nil? || !arg.is_a?(String)
        set_or_return(
          name, arg,
          kind_of: Array, default: [], callbacks: config_search_array_callbacks
        )
      end

      def config_valid_search_array?(s_ary)
        s_ary.each do |s|
          return false unless s.is_a?(String)
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
        return users == '*' if users.is_a?(String)
        users.each do |u|
          return false unless u.is_a?(String) && u.match(/^[a-z0-9\-_]+$/)
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
        rsa_k =
          case k
          when OpenSSL::PKey::RSA then k
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
          return false unless config_valid_key?(k)
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

      def update_from_config!(config)
        OPTIONS.each do |attr|
          value = dup_object(config.send(attr))
          instance_variable_set("@#{attr}", value)
        end
      end

      def update_from_hash!(config)
        config.each do |attr, value|
          attr = attr.to_sym if attr.is_a?(String)
          if OPTIONS.include?(attr)
            value = dup_object(value)
            send(attr, value)
          else
            Chef::Log.warn(
              "#{self.class}: configuration method not found: "\
              "#{attr.to_s.inspect}."
            )
          end
        end
      end
    end
  end
end
