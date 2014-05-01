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
    def load(enc_hs, key)
      body = EncryptedMash.json_create(enc_hs)
      body.decrypt(key)
    end

    # Decrypts a encrypted attribute from a remote node
    def load_from_node(name, attr_ary, key)
      remote_node = RemoteNode.new(name)
      self.load(remote_node.load_attribute(attr_ary, config.partial_search), key)
    end

    # Creates an encrypted attribute from a Hash
    def create(hs, keys=nil)
      body = EncryptedMash.create(config.version)
      body.encrypt(hs, target_keys(keys))
    end

    def create_on_node(name, attr_ary, hs)
      # TODO check attr_ary
      # read the client public key and the node
      node = Chef::Node.load(name)
      node_public_key = Chef::ApiClient.load(name).public_key

      # create the encrypted attribute
      enc_attr = self.create(hs, [ node_public_key ])

      # save encrypted attribute
      last = attr_ary.pop
      node_attr = attr_ary.reduce(node.normal) do |a, k|
        a[k] = Mash.new unless a.has_key?(k)
        a[k]
      end
      node_attr[last] = enc_attr
      node.save
    end

    # Updates the keys for which the attribute is encrypted
    def update(enc_hs, key)
      old_body = EncryptedMash.json_create(enc_hs)
      if old_body.needs_update?(target_keys)
        hs = old_body.decrypt(key)
        new_body = create(hs)
        enc_hs.replace(new_body)
        true
      else
        false
      end
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
      body = EncryptedAttribute.new(self.config(c))
      result = body.load(hs, self.local_node.key)
      Chef::Log.debug("#{self.class.name}: Local Encrypted Attribute loaded.")
      result
    end

    def self.load_from_node(name, attr_ary, c={})
      Chef::Log.debug("#{self.class.name}: Loading Remote Encrypted Attribute from #{name}: #{attr_ary.to_s}")
      body = EncryptedAttribute.new(self.config(c))
      result = body.load_from_node(name, attr_ary, self.local_node.key)
      Chef::Log.debug("#{self.class.name}: Remote Encrypted Attribute loaded.")
      result
    end

    def self.create(hs, c={})
      Chef::Log.debug("#{self.class.name}: Creating Encrypted Attribute.")
      body = EncryptedAttribute.new(self.config(c))
      result = body.create(hs)
      Chef::Log.debug("#{self.class.name}: Encrypted Attribute created.")
      result
    end

    def self.create_on_node(name, attr_ary, hs, c={})
      Chef::Log.debug("#{self.class.name}: Creating Remote Encrypted Attribute on #{name}: #{attr_ary.to_s}")
      body = EncryptedAttribute.new(self.config(c))
      result = body.create_on_node(name, attr_ary, hs)
      Chef::Log.debug("#{self.class.name}: Encrypted Remote Attribute created.")
      result
    end

    def self.update(hs, c={})
      Chef::Log.debug("#{self.class.name}: Updating Encrypted Attribute: #{hs.to_s}")
      body = EncryptedAttribute.new(self.config(c))
      result = body.update(hs, self.local_node.key)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute updated.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not updated.")
      end
      result
    end

    def self.exists?(hs)
      Chef::Log.debug("#{self.class.name}: Checking if Encrypted Attribute exists here: #{hs.to_s}")
      result = EncryptedMash.exists?(hs)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute found.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not found.")
      end
      result
    end

    def self.exists_on_node?(name, attr_ary)
      # TODO check attr_ary
      Chef::Log.debug("#{self.class.name}: Checking if Remote Encrypted Attribute exists on #{name}")
      node = Chef::Node.load(name)
      node_attr = attr_ary.reduce(node.attributes) do |a, k|
        a.kind_of?(Hash) && a.has_key?(k) ? a[k] : nil
      end
      Chef::EncryptedAttribute.exists?(node_attr)
    end

  end
end
