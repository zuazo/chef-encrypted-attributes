require 'chef/encrypted_attribute/attribute_body/version'
require 'chef/encrypted_attribute/attribute_body/version0'

class Chef
  class EncryptedAttribute
    class AttributeBody

      def self.create(version)
        Version.create(version)
      end

      def self.load(enc_attr)
        Version.json_create(enc_attr)
      end

      def self.exists?(enc_attr)
        Version.exists?(enc_attr)
      end

    end
  end
end
