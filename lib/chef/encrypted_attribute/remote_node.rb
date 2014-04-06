require 'chef/encrypted_attribute/search_helper'

class Chef
  class EncryptedAttribute
    class RemoteNode
      extend ::Chef::EncryptedAttribute::SearchHelper

      def initialize(name)
        @name = name
      end

      def name
        @name
      end

      def load_attribute(attr_ary)
        keys = { 'value' => attr_ary }
        self.class.search(:node, "name:#{@name}", keys, 1)[0]['value']
      end

    end
  end
end
