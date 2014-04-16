require 'chef/encrypted_attribute/config'
require 'chef/encrypted_attribute/attribute_body'

class Chef
  class EncryptedAttribute

    def self.config(arg=nil)
      unless arg.nil?
        @@config = Config.new(arg)
      else
        @@config ||= Config.new
      end
    end

    def self.load(hs)
      body = AttributeBody.new(config)
      body.load(hs)
    end

    def self.load_from_node(name, attr_ary)
      body = AttributeBody.new(config)
      body.load_from_node(name, attr_ary)
    end

    def self.create(hs)
      body = AttributeBody.new(config)
      body.create(hs)
    end

    def self.update(hs)
      body = AttributeBody.new(config)
      body.update(hs)
    end

    def self.exists?(hs)
      AttributeBody.exists?(hs)
    end

  end
end
