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
    # Encrypted attributes configuration options object.
    class Config
      include ::Chef::Mixin::ParamsValidate

      # Returns configuration options list.
      #
      # @api private
      OPTIONS = [
        :version,
        :partial_search,
        :client_search,
        :node_search,
        :users,
        :keys
      ].freeze

      # Constructs a {Config} object.
      #
      # @param config [Config, Hash] configuration object to clone.
      def initialize(config = nil)
        update!(config) unless config.nil?
      end

      # Reads or sets Encrypted Mash protocol version.
      #
      # @param arg [String, Fixnum] protocol version to use. Must be a number.
      # @return [Fixnum] protocol version.
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

      # Reads or sets partial search support.
      #
      # Set it to `false` to disable partial search. Defaults to `true`.
      #
      # @param arg [Boolean] whether to enable partial search.
      # @return [Boolean] partial search usage.
      # @see
      #   http://docs.getchef.com/chef_search.html Chef Search documentation
      def partial_search(arg = nil)
        set_or_return(
          :partial_search, arg, kind_of: [TrueClass, FalseClass], default: true
        )
      end

      # Reads or sets client search query.
      #
      # This query will return a list of clients that will be able to read the
      # encrypted attribute.
      #
      # @param arg [String, Array<String>] list of client queries to perform.
      # @return [Array<String>] list of client queries.
      # @see
      #   http://docs.getchef.com/chef_search.html Chef Search documentation
      def client_search(arg = nil)
        set_or_return_search_array(:client_search, arg)
      end

      # Reads or sets node search query.
      #
      # This query will return a list of nodes that will be able to read the
      # encrypted attribute.
      #
      # @param arg [String, Array<String>] list of node queries to perform.
      # @return [Array<String>] list of node queries.
      def node_search(arg = nil)
        set_or_return_search_array(:node_search, arg)
      end

      # Reads or sets user list.
      #
      # This contains the user list that will be able to read the encrypted
      # attribute.
      #
      # @param arg [String, Array<String>] list of users to set.
      # @return [Array<String>] list of users.
      def users(arg = nil)
        set_or_return(
          :users, arg,
          kind_of: [String, Array], default: [],
          callbacks: config_users_arg_callbacks
        )
      end

      # Reads or sets key list.
      #
      # This contains the raw key list that will be able to read the encrypted
      # attribute.
      #
      # @param arg [Array<String, OpenSSL::PKey::RSA>] the keys in PEM format.
      # @return [Array<String, OpenSSL::PKey::RSA>] the keys in PEM format
      def keys(arg = nil)
        set_or_return(
          :keys, arg,
          kind_of: Array, default: [],
          callbacks: config_valid_keys_array_callbacks
        )
      end

      # Replaces the current config.
      #
      # When setting using a {Chef::EncryptedAttribute::Config} class, all the
      # configuration options will be replaced.
      #
      # When setting using a _Hash_, only the provided keys will be replaced.
      #
      # @param config [Config, Hash] the configuration to set.
      # @return [Config] `self`.
      def update!(config)
        if config.is_a?(self.class)
          update_from_config!(config)
        elsif config.is_a?(Hash)
          update_from_hash!(config)
        end
      end

      # Reads a configuration option.
      #
      # @param key [String, Symbol] configuration option to read.
      # @return [Mixed] configuration value.
      def [](key)
        key = key.to_sym if key.is_a?(String)
        send(key) if OPTIONS.include?(key)
      end

      # Sets a configuration option.
      #
      # @param key [String, Symbol] configuration option name to set.
      # @param value [Mixed] configuration value to set.
      # @return [Mixed] configuration value.
      def []=(key, value)
        key = key.to_sym if key.is_a?(String)
        send(key, value) if OPTIONS.include?(key)
      end

      protected

      # Duplicates an object avoiding Ruby exceptions if not supported.
      #
      # @param o [Object] object to duplicate.
      # @return [Object] duplicated object.
      def dup_object(o)
        o.dup
      rescue TypeError
        o
      end

      # Creates getter and setter method for **search array** configuration
      # options.
      #
      # This configuration options contains an array of search queries.
      #
      # @param name [Symbol] configuration option name.
      # @param arg [Array<String>, String] configuration option value to set.
      # @return [Array<String>] configuration option value.
      def set_or_return_search_array(name, arg = nil)
        arg = [arg] unless arg.nil? || !arg.is_a?(String)
        set_or_return(
          name, arg,
          kind_of: Array, default: [], callbacks: config_search_array_callbacks
        )
      end

      # Checks a search query array list.
      #
      # @param s_ary [Array<String>] search query array.
      # @return [Boolean] `true` if the search query list is in the correct
      #   format.
      def config_valid_search_array?(s_ary)
        s_ary.each do |s|
          return false unless s.is_a?(String)
        end
        true
      end

      # Returns configuration option callback function for search arrays.
      #
      # @return [Proc] search arrays checking callback function.
      def config_search_array_callbacks
        {
          'should be a valid array of search patterns' => lambda do |cs|
            config_valid_search_array?(cs)
          end
        }
      end

      # Checks a user list option value.
      #
      # @param users [Array<String>, '*'] user list to check.
      # @return [Boolean] `true` if the user list is in the correct
      #   format.
      def config_valid_user_arg?(users)
        return users == '*' if users.is_a?(String)
        users.each do |u|
          return false unless u.is_a?(String) && u.match(/^[a-z0-9\-_]+$/)
        end
        true
      end

      # Returns configuration option callback function for user lists.
      #
      # @return [Proc] user lists checking callback function.
      def config_users_arg_callbacks
        {
          'should be a valid array of search patterns' => lambda do |us|
            config_valid_user_arg?(us)
          end
        }
      end

      # Checks if an OpenSSL key is in the correct format.
      #
      # Only checks that has a public key. It may lack private key.
      #
      # @param k [String, OpenSSL::PKey::RSA] key to check.
      # @return [Boolean] `true` if the public key is correct.
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

      # Checks if an OpenSSL key array is in the correct format.
      #
      # Only checks that the keys have a public key. They may lack private key.
      #
      # @param k_ary [Array<String, OpenSSL::PKey::RSA>] array of keys to check.
      # @return [Boolean] `true` if the public keys are all correct.
      def config_valid_keys_array?(k_ary)
        k_ary.each do |k|
          return false unless config_valid_key?(k)
        end
        true
      end

      # Returns configuration option callback function for public keys.
      #
      # @return [Proc] public keys checking callback function.
      def config_valid_keys_array_callbacks
        {
          'should be a valid array of keys' => lambda do |keys|
            config_valid_keys_array?(keys)
          end
        }
      end

      # Copies a configuration. All the current configuration options will be
      # replaced.
      #
      # Called by {#update_from!} for {Config} objects.
      #
      # @param config [Config] configuration options to copy.
      def update_from_config!(config)
        OPTIONS.each do |attr|
          value = dup_object(config.send(attr))
          instance_variable_set("@#{attr}", value)
        end
      end

      # Copies a configuration option. Only the provided Hash keys will be
      # replaced, the others will be preserved.
      #
      # Called by {#update_from!} for *Hash* objects.
      #
      # @param config [Hash] configuration options to copy.
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
