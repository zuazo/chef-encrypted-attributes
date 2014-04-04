# require 'chef'
require 'chef/encrypted_attribute/config'
require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/remote_clients'
require 'chef/encrypted_attribute/attribute_body'

class Chef
  class EncryptedAttribute

    def self.config(arg=nil)
      if arg
        @@config = Config.new(arg)
      else
        @@config ||= Config.new
      end
    end

    def self.load(hs)
      local_node = LocalNode.new
      body = AttributeBody.load(hs)
      body.decrypt(local_node.key)
    end

    def self.load_from_node(name, attr_ary)
      remote_node = RemoteNode.new(name)
      self.load(remote_node.load_attribute(attr_ary))
    end

    def self.create(o)
      body = AttributeBody.create(config.version)
      remote_clients = RemoteClients.load(config.client_search)
      keys = remote_clients + config.keys.values
      local_node = LocalNode.new
      keys.push(local_node.public_key)
      body.encrypt(o, keys)
    end

  end
end
