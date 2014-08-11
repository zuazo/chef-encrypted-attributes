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
require 'chef/api_client'

require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/remote_clients'
require 'chef/encrypted_attribute/remote_users'
require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'

Chef::Config[:encrypted_attributes] = Mash.new unless Chef::Config[:encrypted_attributes].kind_of?(Hash)

class Chef
  class EncryptedAttribute

    def initialize(c=nil)
      config(c)
    end

    def config(arg=nil)
      @config ||= EncryptedAttribute::Config.new(Chef::Config[:encrypted_attributes])
      @config.update!(arg) unless arg.nil?
      @config
    end

    # Decrypts an encrypted attribute from a (encrypted) Hash
    def load(enc_hs, key=nil)
      enc_attr = EncryptedMash.json_create(enc_hs)
      decrypted = enc_attr.decrypt(key || local_key)
      decrypted['content'] # TODO check this Hash
    end

    # Decrypts a encrypted attribute from a remote node
    def load_from_node(name, attr_ary, key=nil)
      remote_node = RemoteNode.new(name)
      self.load(remote_node.load_attribute(attr_ary, config.partial_search), key)
    end

    # Creates an encrypted attribute from a Hash
    def create(value, keys=nil)
      decrypted = { 'content' => value }

      enc_attr = EncryptedMash.create(config.version)
      enc_attr.encrypt(decrypted, target_keys(keys))
    end

    def create_on_node(name, attr_ary, value)
      # read the client public key
      node_public_key = Chef::ApiClient.load(name).public_key

      # create the encrypted attribute
      enc_attr = self.create(value, [ node_public_key ])

      # save encrypted attribute
      remote_node = RemoteNode.new(name)
      remote_node.save_attribute(attr_ary, enc_attr)
    end

    # Updates the keys for which the attribute is encrypted
    def update(enc_hs, keys=nil)
      old_enc_attr = EncryptedMash.json_create(enc_hs)
      if old_enc_attr.needs_update?(target_keys(keys))
        hs = old_enc_attr.decrypt(local_key)
        new_enc_attr = create(hs['content'], keys) # TODO check this Hash
        enc_hs.replace(new_enc_attr)
        true
      else
        false
      end
    end

    def update_on_node(name, attr_ary)
      # read the client public key
      node_public_key = Chef::ApiClient.load(name).public_key

      # update the encrypted attribute
      remote_node = RemoteNode.new(name)
      enc_hs = remote_node.load_attribute(attr_ary, config.partial_search)
      updated = update(enc_hs, [ node_public_key ])

      # save encrypted attribute
      if updated
        # TODO Node is accessed twice (here and RemoteNode#load_attribute above)
        remote_node.save_attribute(attr_ary, enc_hs)
      end
      updated
    end

    protected

    def remote_client_keys
      RemoteClients.get_public_keys(config.client_search, config.partial_search)
    end

    def remote_user_keys
      RemoteUsers.get_public_keys(config.users)
    end

    def target_keys(keys=nil)
      target_keys = config.keys + remote_client_keys + remote_user_keys
      target_keys += keys if keys.kind_of?(Array)
      target_keys
    end

    def local_key
      self.class.local_node.key
    end

    def self.local_node
      LocalNode.new
    end

    def self.config(arg)
      config = EncryptedAttribute::Config.new(Chef::Config[:encrypted_attributes])
      config.update!(arg)
      config.keys(config.keys + [ self.local_node.public_key ])
      config
    end

    public

    def self.load(hs, c={})
      Chef::Log.debug("#{self.class.name}: Loading Local Encrypted Attribute from: #{hs.to_s}")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.load(hs)
      Chef::Log.debug("#{self.class.name}: Local Encrypted Attribute loaded.")
      result
    end

    def self.load_from_node(name, attr_ary, c={})
      Chef::Log.debug("#{self.class.name}: Loading Remote Encrypted Attribute from #{name}: #{attr_ary.to_s}")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.load_from_node(name, attr_ary)
      Chef::Log.debug("#{self.class.name}: Remote Encrypted Attribute loaded.")
      result
    end

    def self.create(value, c={})
      Chef::Log.debug("#{self.class.name}: Creating Encrypted Attribute.")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.create(value)
      Chef::Log.debug("#{self.class.name}: Encrypted Attribute created.")
      result
    end

    def self.create_on_node(name, attr_ary, value, c={})
      Chef::Log.debug("#{self.class.name}: Creating Remote Encrypted Attribute on #{name}: #{attr_ary.to_s}")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.create_on_node(name, attr_ary, value)
      Chef::Log.debug("#{self.class.name}: Encrypted Remote Attribute created.")
      result
    end

    def self.update(hs, c={})
      Chef::Log.debug("#{self.class.name}: Updating Encrypted Attribute: #{hs.to_s}")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.update(hs)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute updated.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not updated.")
      end
      result
    end

    def self.update_on_node(name, attr_ary, c={})
      Chef::Log.debug("#{self.class.name}: Updating Remote Encrypted Attribute on #{name}: #{attr_ary.to_s}")
      enc_attr = EncryptedAttribute.new(self.config(c))
      result = enc_attr.update_on_node(name, attr_ary)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Remote Attribute updated.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Remote Attribute not updated.")
      end
      result
    end

    def self.exist?(hs)
      Chef::Log.debug("#{self.class.name}: Checking if Encrypted Attribute exists here: #{hs.to_s}")
      result = EncryptedMash.exist?(hs)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute found.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not found.")
      end
      result
    end

    def self.exists?(*args)
      Chef::Log.warn("#{self.name}.exists? is deprecated in favor of #{self.name}.exist?.")
      exist?(*args)
    end

    def self.exist_on_node?(name, attr_ary, c={})
      Chef::Log.debug("#{self.class.name}: Checking if Remote Encrypted Attribute exists on #{name}")
      remote_node = RemoteNode.new(name)
      node_attr = remote_node.load_attribute(attr_ary, self.config(c).partial_search)
      Chef::EncryptedAttribute.exist?(node_attr)
    end

    def self.exists_on_node?(*args)
      Chef::Log.warn("#{self.name}.exists_on_node? is deprecated in favor of #{self.name}.exist_on_node?.")
      exist_on_node?(*args)
    end

  end
end
