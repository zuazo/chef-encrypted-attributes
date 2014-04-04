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
        # escaped_query = escape("name:#{@name}", Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
        # node = query.search(:node, escaped_query, nil, 0, 1)[0][0]
        # attr_ary.reduce(node) do |n, k|
        #   n.respond_to?(:has_key?) && n.has_key?(k) ? n[k] : nil
        # end
      end

    end
  end
end
