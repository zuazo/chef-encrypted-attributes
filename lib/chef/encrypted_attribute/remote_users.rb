# encoding: UTF-8
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

require 'chef/user'
require 'chef/encrypted_attribute/exceptions'
require 'chef/encrypted_attribute/cache_lru'

class Chef
  class EncryptedAttribute
    # Helpers to get remote Chef Users keys.
    #
    # @note This class methods require **admin** privileges.
    class RemoteUsers
      # Remote users public keys cache.
      #
      # You can disable it setting it's size to zero:
      #
      # ```ruby
      # Chef::EncryptedAttribute::RemoteUsers.cache.max_size(0)
      # ```
      #
      # @return [CacheLru] Remote users LRU cache.
      def self.cache
        @@cache ||= Chef::EncryptedAttribute::CacheLru.new
      end

      # Gets some Chef users public keys.
      #
      # @note This method requires **admin** privileges.
      #
      # @param users [Array<String>, '*'] user list. Use `'*'` to get all users
      #   public keys.
      # @return [Array<String>] public key list.
      # @raise [ArgumentError] if user list is wrong.
      def self.get_public_keys(users = [])
        if users == '*' # users are [a-z0-9\-_]+, cannot be *
          cache.key?('*') ? cache['*'] : cache['*'] = all_public_keys
        elsif users.is_a?(Array)
          get_users_public_keys(users)
        elsif !users.nil?
          fail ArgumentError,
               "#{self.class}##{__method__} users argument must be an array "\
               'or "*".'
        end
      end

      # Reads a Chef user public key.
      #
      # @note This method requires **admin** privileges.
      #
      # @param name [String] user name.
      # @return [String] user public key as string.
      # @raise [InsufficientPrivileges] if you lack enough privileges to read
      #   the keys from the Chef Server.
      # @api private
      def self.get_user_public_key(name)
        return cache[name] if cache.key?(name)
        user = Chef::User.load(name)
        cache[name] = user.public_key
      rescue Net::HTTPServerException => e
        case e.response.code
        when '403'
          raise InsufficientPrivileges,
                'Your node needs admin privileges to be able to work with '\
                'Chef Users.'
        when '404' then raise UserNotFound, "Chef User not found: \"#{name}\"."
        else
          raise e
        end
      end

      # Gets some Chef users public keys.
      #
      # @note This method requires **admin** privileges.
      #
      # @param users [Array<String>] user list.
      # @return [Array<String>] public key list.
      # @api private
      def self.get_users_public_keys(users)
        users.map { |n| get_user_public_key(n) }
      end

      # Gets all Chef users public keys.
      #
      # @note This method requires **admin** privileges.
      #
      # @return [Array<String>] public key list.
      # @api private
      def self.all_public_keys
        # Chef::User.list(inflate=true) has a bug (fixed in 11.14.0)
        # https://tickets.opscode.com/browse/CHEF-5328
        get_users_public_keys(Chef::User.list.keys)
      end
    end
  end
end
