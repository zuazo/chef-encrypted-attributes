require 'chef/encrypted_attribute/search_helper'

class Chef
  class EncryptedAttribute
    class RemoteClients
      extend ::Chef::EncryptedAttribute::SearchHelper

      def self.load(search=nil)
        search(:client, search, {
          'public_key' => [ 'public_key' ]
        }).map do |client|
          client['public_key']
        end.compact
      end

    end
  end
end
