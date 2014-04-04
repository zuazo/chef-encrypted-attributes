
class Chef
  class EncryptedAttribute
    class AttributeBody

      # TODO separate files?
      class Version

        def initialize(enc_attr=nil)
          @enc_attr =
            if enc_attr.nil?
              {
                '_encryted_attribute' => true,
                '_version' => version,
              }
            else
              enc_attr
            end
        end

        def encrypt
          raise "#{self.class.to_s}##{__method__} method not implemented."
        end

        def decrypt
          raise "#{self.class.to_s}##{__method__} method not implemented."
        end

        def enc_attr
          @enc_attr
        end

        def version
          self.class.to_s.sub(/^#{Regexp.escape(self.class.superclass.name)}/, '')
        end

      end # Version

      class Version0 < Version
        # TODO HMAC_ALGORITHM = 'sha256'

        def encrypt(value, public_keys)
          value = value.to_json
          @enc_attr['_encrypted_rsa_data'] = Mash.new(Hash[
            public_keys.map do |public_key|
              [
                node_key(public_key),
                encrypt_value(public_key, value),
              ]
            end
          ])
          @enc_attr
        end

        def decrypt(key)
          # TODO check input and enc_attr
          enc_value = @enc_attr['_encrypted_rsa_data'][node_key(key.public_key)]
          decrypt_value(key, enc_value)
        end

        protected

        def node_key(public_key)
          if public_key.kind_of?(String)
            public_key = OpenSSL::PKey::RSA.new(public_key)
          end
          Digest::SHA1.hexdigest(public_key.to_der)
        end

        def encrypt_value(public_key, value)
          if public_key.kind_of?(String)
            public_key = OpenSSL::PKey::RSA.new(public_key)
          end
          Base64.encode64(public_key.public_encrypt(value))
        end

        def decrypt_value(key, value)
          key.private_decrypt(Base64.decode64(value))
        end

      end # Version0

      def self.create(version)
        create_class(version)
      end

      def self.load(enc_attr)
        # TODO check input
        version = enc_attr['_version']
        create_class(version, enc_attr)
      end

      protected

      def self.version_class(version)
        version = version.to_s unless version.kind_of?(String)
        return nil if version.empty?
        begin
          class_name = "#{name.to_s}::Version#{version}"
          if RUBY_VERSION < '1.9'
            class_name.split('::').inject(Kernel) { |scope, const| scope.const_get(const) }
          else
            class_name.split('::').inject(Kernel) { |scope, const| scope.const_get(const, scope === Kernel) }
          end
        rescue NameError => e
          Chef::Log.error(e) # TODO remove this
          nil
        end
      end

      def self.create_class(version, enc_attr=nil)
        klass = version_class(version)
        if klass.nil?
          # TODO create an exception class
          raise "This version of chef-encrypted-attribute does not support encrypted attribute item format version '#{version}'"
        else
          klass.send(:new, enc_attr)
        end
      end

    end
  end
end
