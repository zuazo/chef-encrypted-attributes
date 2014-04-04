class Chef
  class EncryptedAttribute
    class LocalNode

      def name
        Chef::Config[:node_name]
      end

      def key
        OpenSSL::PKey::RSA.new(open(Chef::Config[:client_key]).read())
      end

      def public_key
        key.public_key
      end

    end
  end
end
