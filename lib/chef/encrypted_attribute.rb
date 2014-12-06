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
  # Main EncryptedAttribute class, includes instance and class API methods
  class EncryptedAttribute
    extend Chef::EncryptedAttribute::API

    def initialize(c = nil)
      config(c)
    end

    def config(arg = nil)
      @config ||= EncryptedAttribute::Config.new(
        Chef::Config[:encrypted_attributes]
      )
      @config.update!(arg) unless arg.nil?
      @config
    end

    # Decrypts an encrypted attribute from a (encrypted) Hash
    def load(enc_hs, key = nil)
      enc_attr = EncryptedMash.json_create(enc_hs)
      decrypted = enc_attr.decrypt(key || local_key)
      decrypted['content'] # TODO: check this Hash
    end

    # Decrypts a encrypted attribute from a remote node
    def load_from_node(name, attr_ary, key = nil)
      remote_node = RemoteNode.new(name)
      load(remote_node.load_attribute(attr_ary, config.partial_search), key)
    end

    # Creates an encrypted attribute from a Hash
    def create(value, keys = nil)
      decrypted = { 'content' => value }

      enc_attr = EncryptedMash.create(config.version)
      enc_attr.encrypt(decrypted, target_keys(keys))
    end

    def create_on_node(name, attr_ary, value)
      # read the client public key
      node_public_key = RemoteClients.get_public_key(name)

      # create the encrypted attribute
      enc_attr = create(value, [node_public_key])

      # save encrypted attribute
      remote_node = RemoteNode.new(name)
      remote_node.save_attribute(attr_ary, enc_attr)
    end

    # Updates the keys for which the attribute is encrypted
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

    def remote_client_keys
      RemoteClients.search_public_keys(
        config.client_search, config.partial_search
      )
    end

    def remote_node_keys
      RemoteNodes.search_public_keys(config.node_search, config.partial_search)
    end

    def remote_user_keys
      RemoteUsers.get_public_keys(config.users)
    end

    def target_keys(keys = nil)
      target_keys =
        config.keys + remote_client_keys + remote_node_keys + remote_user_keys
      target_keys += keys if keys.is_a?(Array)
      target_keys
    end

    def local_key
      LocalNode.new.key
    end
  end
end
