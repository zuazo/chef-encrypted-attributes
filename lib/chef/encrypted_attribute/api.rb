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

require 'chef/encrypted_attribute/config'
require 'chef/encrypted_attribute/encrypted_mash'
require 'chef/config'

require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'
require 'chef/encrypted_attribute/encrypted_mash/version2'

class Chef
  class EncryptedAttribute
    # Main EncryptedAttribute class methods API module.
    #
    # All these methods are available as static methods of the
    # {Chef::EncryptedAttribute} class.
    #
    # These methods are intended to be used from Chef
    # [Recipes](http://docs.getchef.com/recipes.html) or
    # [Resources](https://docs.getchef.com/resource.html).
    #
    # This module uses the {Chef::EncryptedAttribute} instance methods
    # internally.
    #
    # # Configuration
    #
    # All the methods read the default configuration from the
    # `Chef::Config[:encrypted_attributes]` hash. Most of methods also support
    # setting some configuration parameters as last argument. Both the global
    # and the method argument configuration will be merged.
    #
    # If the configuration value to be merged is an array or a hash (for example
    # `keys`), the method argument configuration value has preference over the
    # global configuration. arrays and hashes are not merged.
    #
    # Both `Chef::Config[:encrypted_attributes]` and method's `config` parameter
    # should be a hash which may have any of the following keys:
    #
    # * `:version` - `EncryptedMash` format version to use, by default `1` is
    #   used which is recommended. The version `2` uses [GCM]
    #   (http://en.wikipedia.org/wiki/Galois/Counter_Mode) and probably should
    #   be considered the most secure, but it is disabled by default because it
    #   has some more requirements: Ruby `>= 2` and OpenSSL `>= 1.0.1`.
    # * `:partial_search` - Whether to use Chef Server partial search, enabled
    #   by default. It may not work in some old versions of Chef Server.
    # * `:client_search` - Search query for clients allowed to read the
    #   encrypted attribute. Can be a simple string or an array of queries to be
    #   *OR*-ed.
    # * `:node_search` - Search query for nodes allowed to read the encrypted
    #   attribute. Can be a simple string or an array of queries to be *OR*-ed.
    # * `:users` - Array of user names to be allowed to read the encrypted
    #   attribute(s). `"*"` to allow access to all users. Keep in mind that only
    #   admin clients or admin users are allowed to read user public keys. It is
    #   **not recommended** to use this from cookbooks unless you know what you
    #   are doing.
    # * `:keys` - raw RSA public keys to be allowed to read encrypted
    #   attributes(s), in PEM (string) format. Can be client public keys, user
    #   public keys or any other RSA public key.
    #
    # @see Config
    #
    # For example, to disable Partial Search globally:
    #
    # ```ruby
    # Chef::Config[:encrypted_attributes][:partial_search] = false
    #
    # # ftp_pass = Chef::EncryptedAttribute.load(node['myapp']['ftp_password'])
    # # ...
    # ```
    #
    # To disable Partial Search locally:
    #
    # ```ruby
    # ftp_pass = Chef::EncryptedAttribute.load(
    #   node['myapp']['ftp_password'], { :partial_search => false }
    # )
    # ```
    #
    # To use protocol version 2 globally, which uses [GCM]
    # (http://en.wikipedia.org/wiki/Galois/Counter_Mode):
    #
    # ```ruby
    # Chef::Config[:encrypted_attributes][:version] = 2
    # # ...
    # ```
    #
    # If you want to use knife to work with encrypted attributes, surely you
    # will need to save your Chef User public keys in a Data Bag (there is no
    # need to encrypt them because they are public) and add them to the `:keys`
    # configuration option. See the [Example Using User Keys Data Bag]
    # (README.md#example-using-user-keys-data-bag) in the README for more
    # information on this.
    #
    # # Caches
    #
    # This API uses some LRU caches to avoid making many requests to the Chef
    # Server. All the caches are global and has the following methods:
    #
    # * `max_size` - Gets or sets the cache maximum item size.
    # * `clear` - To empty the cache.
    # * `[]` - To read a cache value (used internally).
    # * `[]=` - To set a cache value (used internally).
    #
    # @see CacheLru
    #
    # This are the currently available caches:
    #
    # * `Chef::EncryptedAttribute::RemoteClients.cache` - Caches the
    #   `:client_search` query results (max_size: `1024`).
    # * `Chef::EncryptedAttribute::RemoteNodes.cache` - Caches the
    #   `:node_search` query results (max_size: `1024`).
    # * `Chef::EncryptedAttribute::RemoteUsers.cache` - Caches the Chef Users
    #   public keys (max_size: `1024`).
    # * `Chef::EncryptedAttribute::RemoteNode.cache` - Caches the node
    #   (encrypted) attributes. Disabled by default (max_size: `0`).
    #
    # ### Clear All the Caches
    #
    # You can clear all the caches with the following code:
    #
    # ```ruby
    # Chef::EncryptedAttribute::RemoteClients.cache.clear
    # Chef::EncryptedAttribute::RemoteNodes.cache.clear
    # Chef::EncryptedAttribute::RemoteUsers.cache.clear
    # Chef::EncryptedAttribute::RemoteNode.cache.clear
    # ```
    #
    # ### Disable All the Caches
    #
    # You can disable all the caches with the following code:
    #
    # ```ruby
    # Chef::EncryptedAttribute::RemoteClients.cache.max_size(0)
    # Chef::EncryptedAttribute::RemoteNodes.cache.max_size(0)
    # Chef::EncryptedAttribute::RemoteUsers.cache.max_size(0)
    # Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)
    # ```
    #
    # @see RemoteClients.cache
    # @see RemoteNodes.cache
    # @see RemoteUsers.cache
    # @see RemoteNode.cache
    module API
      # Prints a Chef debug message.
      #
      # @param msg [String] message to print.
      # @return void
      # @api private
      def debug(msg)
        Chef::Log.debug("Chef::EncryptedAttribute: #{msg}")
      end

      # Prints a Chef warning message.
      #
      # @param msg [String] message to print.
      # @return void
      # @api private
      def warn(msg)
        Chef::Log.warn(msg)
      end

      # Gets local node object.
      #
      # @return [LocalNode] local node object.
      # @api private
      def local_node
        LocalNode.new
      end

      # Creates a new {Config} object.
      #
      # Reads the default configuration from
      # `Chef::Config[:encrypted_attributes]`.
      #
      # When the parameter is a {Chef::EncryptedAttribute::Config} class, all
      # the configuration options will be replaced.
      #
      # When the parameter is a _Hash_, only the provided keys will be replaced.
      #
      # The local node public key will always be added to the provided
      # configuration keys.
      #
      # @param arg [Config, Hash] the configuarion to set.
      # @return [Config] the read or set configuration object.
      # @api private
      def config(arg)
        config =
          EncryptedAttribute::Config.new(Chef::Config[:encrypted_attributes])
        config.update!(arg)
        config.keys(config.keys + [local_node.public_key])
        config
      end

      # Reads an encrypted attribute from a hash, usually a node attribute.
      #
      # Uses the local private key to decrypt the attribute.
      #
      # An exception is thrown if the attribute cannot be decrypted or no
      # encrypted attribute is found.
      #
      # @param enc_hs [Mash] an encrypted hash, usually a node attribute. For
      #   example: `node['myapp']['ftp_password']`.
      # @param c [Config, Hash] a configuration hash. For example:
      #   `{ :partial_search => false }`.
      # @return [Hash, Array, String, ...] the attribute in clear text,
      #   decrypted.
      def load(enc_hs, c = {})
        debug("Loading Local Encrypted Attribute from: #{enc_hs.inspect}")
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.load(enc_hs)
        debug('Local Encrypted Attribute loaded.')
        result
      end

      # Reads an encrypted attribute from a remote node.
      #
      # Uses the local private key to decrypt the attribute.
      #
      # An exception is thrown if the attribute cannot be decrypted or no
      # encrypted attribute is found.
      #
      # @param name [String] the node name.
      # @param attr_ary [Array<String>] the attribute path as *array of
      #   strings*. For example: `%w(myapp ftp_password)`.
      # @param c [Config, Hash] a configuration hash. For example:
      #   `{ :partial_search => false }`.
      # @return [Hash, Array, String, ...] decrypted attribute value.
      def load_from_node(name, attr_ary, c = {})
        debug(
          "Loading Remote Encrypted Attribute from #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.load_from_node(name, attr_ary)
        debug('Remote Encrypted Attribute loaded.')
        result
      end

      # Creates an encrypted attribute.
      #
      # The returned value should be saved in a node attribute, like
      # `node.normal[...] = Chef::EncryptedAttribute.create(...)`.
      #
      # The local node will always be able to decrypt the attribute.
      #
      # An exception is thrown if any error arises in the encryption process.
      #
      # @param value [Hash, Array, String, ...] the value to be encrypted. Can
      #   be a boolean, a number, a string, an array or a hash (the value will
      #   be converted to JSON internally).
      # @param c [Config, Hash] a configuration hash. For example:
      #   `{ :client_search => "admin:true" }`.
      # @return [EncryptedMash] encrypted attribute value. This is usually what
      #   is saved in the node attributes.
      def create(value, c = {})
        debug('Creating Encrypted Attribute.')
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.create(value)
        debug('Encrypted Attribute created.')
        result
      end

      # Creates an encrypted attribute on a remote node.
      #
      # Both the local node and the remote node will be able to decrypt the
      # attribute.
      #
      # This method **requires admin privileges**. So in most cases, cannot be
      # used from cookbooks.
      #
      # An exception is thrown if any error arises in the encryption process.
      #
      # @param name [String] the node name.
      # @param attr_ary [Array<String>] the attribute path as *array of
      #   strings*. For example: `%w(myapp ftp_password)`.
      # @param value [Hash, Array, String, Fixnum, ...] the value to be
      #   encrypted. Can be a boolean, a number, a string, an array or a hash
      #   (the value will be converted to JSON internally).
      # @param c [Config, Hash] a configuration hash. For example:
      #   `{ :client_search => 'admin:true' }`.
      # @return [EncryptedMash] encrypted attribute value.
      def create_on_node(name, attr_ary, value, c = {})
        debug(
          "Creating Remote Encrypted Attribute on #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.create_on_node(name, attr_ary, value)
        debug('Encrypted Remote Attribute created.')
        result
      end

      # Updates who can read the attribute. This is intended to be used to
      # update to the new nodes returned by `:client_search` and `:node_search`
      # or perhaps global configuration changes.
      #
      # For example, in case new nodes are added or some are removed, and the
      # clients returned by `:client_search` or `:node_search` are different,
      # this `#update` method will decrypt the attribute and encrypt it again
      # for the new nodes (or remove the old ones).
      #
      # If an update is made, the shared secrets are regenerated.
      #
      # Both the local node and the remote node will be able to decrypt the
      # attribute.
      #
      # An exception is thrown if there is any error in the updating process.
      #
      # @param enc_hs This must be a node encrypted attribute, this attribute
      #   will be updated, so it is mandatory to specify the type (usually
      #   `normal`). For example: `node.normal['myapp']['ftp_password']`.
      # @param c [Config, Hash] a configuration hash. Surely you want this
      #   `#update` method to use the same `config` that the `#create` call.
      # @return [Boolean] `true` if the encrypted attribute has been updated,
      #   `false` if not.
      def update(enc_hs, c = {})
        debug("Updating Encrypted Attribute: #{enc_hs.inspect}")
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.update(enc_hs)
        if result
          debug('Encrypted Attribute updated.')
        else
          debug('Encrypted Attribute not updated.')
        end
        result
      end

      # Updates who can decrypt the remote attribute.
      #
      # This method **requires admin privileges**. So in most cases, cannot be
      # used from cookbooks.
      #
      # An exception is thrown if there is any error in the updating process.
      #
      # @param name [String] the node name.
      # @param attr_ary [Array<String>] the attribute path as *array of
      #   strings*. For example: `%w(myapp ftp_password)`.
      # @param c [Config, Hash] a configuration hash. Surely you want this
      #   `#update_on_node` method to use the same `config` that the `#create`
      #   call.
      # @return [Boolean] `true` if the encrypted attribute has been updated,
      #   `false` if not.
      def update_on_node(name, attr_ary, c = {})
        debug(
          "Updating Remote Encrypted Attribute on #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.update_on_node(name, attr_ary)
        debug("Encrypted Remote Attribute #{result ? '' : 'not '}updated.")
        result
      end

      # Checks whether an encrypted attribute exists.
      #
      # @param hs [Mash] an encrypted hash, usually a node attribute. The
      #   attribute type can be specified but is not necessary. For example:
      #   `node['myapp']['ftp_password']`.
      # @return [Boolean] `true` if an encrypted attribute is found, `false` if
      #   not.
      def exist?(hs)
        debug("Checking if Encrypted Attribute exists here: #{hs.inspect}")
        result = EncryptedMash.exist?(hs)
        debug("Encrypted Attribute #{result ? '' : 'not '}found.")
        result
      end

      # Checks whether an encrypted attribute exists in a remote node.
      #
      # @param args {#exist?} arguments.
      # @return [Boolean] `true` if an encrypted attribute is found, `false` if
      #   not.
      # @deprecated Use {#exist?} instead.
      def exists?(*args)
        warn("#{name}.exists? is deprecated in favor of #{name}.exist?.")
        exist?(*args)
      end

      # Checks whether an encrypted attribute exists in a remote node.
      #
      # @param name [String] the node name.
      # @param attr_ary [Array<String>] the attribute path as *array of
      #   strings*. For example: `%w(myapp ftp_password)`.
      # @param c [Config, Hash] a configuration hash. For example:
      #   `{ :partial_search => false }`.
      # @return [Boolean] `true` if an encrypted attribute is found, `false` if
      #   not.
      def exist_on_node?(name, attr_ary, c = {})
        debug("Checking if Remote Encrypted Attribute exists on #{name}")
        remote_node = RemoteNode.new(name)
        node_attr =
          remote_node.load_attribute(attr_ary, config(c).partial_search)
        Chef::EncryptedAttribute.exist?(node_attr)
      end

      # Checks whether an encrypted attribute exists in a remote node.
      #
      # @param args {#exist_on_node?} arguments.
      # @return [Boolean] `true` if an encrypted attribute is found, `false` if
      #   not.
      # @deprecated Use {#exist_on_node?} instead.
      def exists_on_node?(*args)
        warn(
          "#{name}.exists_on_node? is deprecated in favor of "\
          "#{name}.exist_on_node?."
        )
        exist_on_node?(*args)
      end
    end
  end
end
