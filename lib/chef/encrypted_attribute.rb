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
require 'chef/mash'

require 'chef/encrypted_attribute/api'
require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/remote_nodes'
require 'chef/encrypted_attribute/remote_clients'
require 'chef/encrypted_attribute/remote_users'
require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'
require 'chef/encrypted_attribute/encrypted_mash/version2'

unless Chef::Config[:encrypted_attributes].is_a?(Hash)
  Chef::Config[:encrypted_attributes] = Mash.new
end

class Chef
  # Main EncryptedAttribute class. Includes instance and class API methods.
  #
  # The *class methods* (or static methods) are normally used **from Chef
  # cookbooks**. They are documented in the {Chef::EncryptedAttribute::API}
  # class.
  #
  # The *instance methods* are normally used **by other libraries or gems**. For
  # example, the knife extensions included in this gem uses these methods.
  #
  # @see EncryptedAttribute::API
  class EncryptedAttribute
    # Include the *class methods* for the recipe API.
    extend Chef::EncryptedAttribute::API

    # Chef::EncryptedAttribute constructor.
    #
    # @param c [Config, Hash] configuration to use.
    def initialize(c = nil)
      config(c)
    end

    # Sets or gets the encrypted attribute configuration.
    #
    # Reads the default configuration from
    # `Chef::Config[:encrypted_attributes]`.
    #
    # When setting using a {Chef::EncryptedAttribute::Config} class, all the
    # configuration options will be replaced.
    #
    # When setting using a _Hash_, only the provided keys will be replaced.
    #
    # @param arg [Config, Hash] the configuarion to set.
    # @return [Config] the read or set configuration object.
    def config(arg = nil)
      @config ||= EncryptedAttribute::Config.new(
        Chef::Config[:encrypted_attributes]
      )
      @config.update!(arg) unless arg.nil?
      @config
    end

    # Decrypts an encrypted attribute from a local node attribute.
    #
    # @param enc_hs [Mash] the encrypted hash as read from the node attributes.
    # @param key [OpenSSL::PKey::RSA, String] private key to use in the
    #   decryption process, uses the local node key by default.
    # @return [Hash, Array, String, ...] decrypted attribute value.
    def load(enc_hs, key = nil)
      enc_attr = EncryptedMash.json_create(enc_hs)
      decrypted = enc_attr.decrypt(key || local_key)
      decrypted['content'] # TODO: check this Hash
    end

    # Decrypts a encrypted attribute from a remote node.
    #
    # @param name [String] node name.
    # @param attr_ary [Array<String>] node attribute path as Array.
    # @param key [OpenSSL::PKey::RSA, String] private key to use in the
    #   decryption process, uses the local key by default.
    # @return [Hash, Array, String, ...] decrypted attribute value.
    def load_from_node(name, attr_ary, key = nil)
      remote_node = RemoteNode.new(name)
      load(remote_node.load_attribute(attr_ary, config.partial_search), key)
    end

    # Creates an encrypted attribute from a Hash.
    #
    # Only the **keys passed as parameter and the configured keys** will be able
    # to decrypt the attribute, so beware of including your local key if you
    # need to decrypt it in the future.
    #
    # @param value [Hash, Array, String, Fixnum, ...] the value to encrypt in
    #   clear.
    # @param keys [OpenSSL::PKey::RSA, String] public keys that will be able to
    #   decrypt the attribute.
    # @return [EncryptedMash] encrypted attribute value. This is usually what is
    #   saved in the node attributes.
    def create(value, keys = nil)
      decrypted = { 'content' => value }

      enc_attr = EncryptedMash.create(config.version)
      enc_attr.encrypt(decrypted, target_keys(keys))
    end

    # Creates an encrypted attribute on a remote node.
    #
    # The remote node will always be able to decrypt it. The local node will
    # not be able to decrypt it by default, you must remember to include the key
    # in the configuration.
    #
    # @param name [String] node name.
    # @param attr_ary [Array<String>] node attribute path as Array.
    # @param value [Hash, Array, String, Fixnum, ...] the value to encrypt.
    # @return [EncryptedMash] encrypted attribute value.
    def create_on_node(name, attr_ary, value)
      # read the client public key
      node_public_key = RemoteClients.get_public_key(name)

      # create the encrypted attribute
      enc_attr = create(value, [node_public_key])

      # save encrypted attribute
      remote_node = RemoteNode.new(name)
      remote_node.save_attribute(attr_ary, enc_attr)
    end

    # Updates the keys for which a local attribute is encrypted.
    #
    # In case new keys are added or some keys are removed, the attribute will
    # be re-created again.
    #
    # Only the **keys passed as parameter and the configured keys** will be able
    # to decrypt the attribute, so beware of including your local key if you
    # need to decrypt it in the future.
    #
    # Uses the local key to decrypt the attribute, so the local key should be
    # able to read the attribute. At least before updating.
    #
    # @param enc_hs [Mash] encrypted attribute. This parameter value will be
    #   modified on updates.
    # @param keys [Array<OpenSSL::PKey::RSA, String> public keys that should be
    #   able to read the attribute.
    # @return [Boolean] Returns `true` if the encrypted attribute (the *Mash*
    #   parameter) has been updated.
    # @see #config
    def update(enc_hs, keys = nil)
      old_enc_attr = EncryptedMash.json_create(enc_hs)
      if old_enc_attr.needs_update?(target_keys(keys))
        hs = old_enc_attr.decrypt(local_key)
        new_enc_attr = create(hs['content'], keys) # TODO: check this Hash
        enc_hs.replace(new_enc_attr)
        true
      else
        false
      end
    end

    # Updates the keys for which a remote attribute is encrypted.
    #
    # In case new keys are added or some keys are removed, the attribute will
    # be re-created again.
    #
    # Only the **remote node and the configured keys** will be able to decrypt
    # the attribute, so beware of including your local key if you need to
    # decrypt it in the future.
    #
    # Uses the local key to decrypt the attribute, so the local key should be
    # able to read the attribute. At least before updating.
    #
    # @param name [String] node name.
    # @param attr_ary [Array<String>] node attribute path as Array.
    # @return [Boolean] Returns `true` if the remote encrypted attribute has
    #   been updated.
    # @see #config
    def update_on_node(name, attr_ary)
      # read the client public key
      node_public_key = RemoteClients.get_public_key(name)

      # update the encrypted attribute
      remote_node = RemoteNode.new(name)
      enc_hs = remote_node.load_attribute(attr_ary, config.partial_search)
      updated = update(enc_hs, [node_public_key])

      # save encrypted attribute
      if updated
        # TODO: Node is accessed twice (RemoteNode#load_attribute above)
        remote_node.save_attribute(attr_ary, enc_hs)
      end
      updated
    end

    protected

    # Gets remote client public keys using the *client search* query included in
    # the configuration.
    #
    # @return [Array<String>] list of client public keys.
    # @see config
    def remote_client_keys
      RemoteClients.search_public_keys(
        config.client_search, config.partial_search
      )
    end

    # Gets remote node public keys using the *node search* query included in the
    # configuration.
    #
    # @return [Array<String>] list of node public keys.
    # @see config
    def remote_node_keys
      RemoteNodes.search_public_keys(config.node_search, config.partial_search)
    end

    # Gets remote user keys using the configured user list.
    #
    # @return [Array<String>] list of user public keys.
    # @see config
    def remote_user_keys
      RemoteUsers.get_public_keys(config.users)
    end

    # Gets the public keys that should be able to read the attribute based on
    # the configuration.
    #
    # This includes keys passed as parameter, configured keys,
    # #remote_client_keys, #remote_node_keys and remote_user_keys.
    #
    # @param keys [Array<String>] list of public keys to include in addition to
    #   the configured.
    # @return [Array<String>] list of user public keys.
    # @see config
    # @see remote_client_keys
    # @see remote_node_keys
    # @see remote_user_keys
    def target_keys(keys = nil)
      target_keys =
        config.keys + remote_client_keys + remote_node_keys + remote_user_keys
      target_keys += keys if keys.is_a?(Array)
      target_keys
    end

    # Gets the local private key.
    #
    # @return [OpenSSL::PKey::RSA.new] local private (and public) key object.
    def local_key
      LocalNode.new.key
    end
  end
end
