
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

        def can_be_decrypted_by?
          raise "#{self.class.to_s}##{__method__} method not implemented."
        end

        def needs_update?(keys)
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
          public_keys = remove_dup_keys(public_keys)
          @enc_attr['_encrypted_rsa_data'] = Mash.new(Hash[
            public_keys.map do |public_key|
              [
                node_key(public_key),
                encrypt_value(public_key, json_encode(value)),
              ]
            end
          ])
          @enc_attr
        end

        def decrypt(key)
          # TODO check input and enc_attr
          enc_value = @enc_attr['_encrypted_rsa_data'][node_key(key.public_key)]
          json_decode(decrypt_value(key, enc_value))
        end

        def can_be_decrypted_by?(keys)
          remove_dup_keys(keys).reduce(true) do |r, k|
            r and @enc_attr['_encrypted_rsa_data'].kind_of?(Hash) and
              @enc_attr['_encrypted_rsa_data'].has_key?(node_key(k))
          end
        end

        def needs_update?(keys)
          keys = remove_dup_keys(keys)
          not can_be_decrypted_by?(keys) && @enc_attr['_encrypted_rsa_data'].keys.count == keys.count
        end

        protected

        def remove_dup_keys(keys)
          keys = [ keys ].flatten
          keys.map do |k|
            k.kind_of?(String) ? k = OpenSSL::PKey::RSA.new(k) : k
          end.uniq { |k| k.public_key.to_s.chomp }
        end

        def json_encode(o)
          # Array to avoid using quirks mode, create standard JSON
          [ o ].to_json
        end

        def json_decode(o)
          # TODO invalid JSON exception
          JSON.parse(o)[0]
        end

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
