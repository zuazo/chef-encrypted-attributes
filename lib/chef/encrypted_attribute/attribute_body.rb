
class Chef
  class EncryptedAttribute
    class AttributeBody

      # TODO separate files?
      class Version < Mash

        # This class is oriented to be easily integrable with
        # chef in the future using JSONCompat

        JSON_CLASS =      'x_json_class'.freeze
        CHEF_TYPE =       'x_chef_type'.freeze # TODO "x_" not needed here?
        CHEF_TYPE_VALUE = 'encrypted_attribute'.freeze

        def initialize(enc_attr=nil)
          super
          self[JSON_CLASS] = self.class.name
          self[CHEF_TYPE] = CHEF_TYPE_VALUE
          # TODO better to use is_a? ?
          update_from!(enc_attr) if enc_attr.kind_of?(Hash)
        end

        %w{encrypt decrypt can_be_decrypted_by? needs_update?}.each do |meth|
          define_method(meth) do
            raise "#{self.class.to_s}##{__method__} method not implemented."
          end
        end

        def self.exists?(enc_attr)
          enc_attr.kind_of?(Hash) and
          enc_attr.has_key?(JSON_CLASS) and
          enc_attr[JSON_CLASS] =~ /^#{Regexp.escape(Module.nesting[1].name)}/ and
          enc_attr.has_key?(CHEF_TYPE) and enc_attr[CHEF_TYPE] == CHEF_TYPE_VALUE
        end

        def self.create(version, o=nil)
          klass = version_klass(version)
          klass.send(:new, o)
        end

        # Serialize this object as a hash
        def to_json(*a)
          for_json.to_json(*a)
        end

        # Returns a Hash for JSON
        # TODO not needed method?
        def for_json
          to_hash
        end

        # Update the AttributeBody from Hash
        def update_from!(o)
          unless self.class.exists?(o)
            raise 'Trying to construct invalid encrypted attribute. Perhaps is not encrypted?'
          end
          o = o.dup
          o.delete(JSON_CLASS)
          o.delete(CHEF_TYPE)
          update(o)
        end

        # Create a AttributeBody::Version from JSON
        def self.json_create(o)
          klass = string_to_klass(o[JSON_CLASS])
          if klass.nil?
            raise "Unknown chef-encrypted-attribute class '#{o[JSON_CLASS]}'"
          end
          klass.send(:new, o)
        end

        protected

        def self.string_to_klass(class_name)
          begin
            if RUBY_VERSION < '1.9'
              class_name.split('::').inject(Kernel) { |scope, const| scope.const_get(const) }
            else
              class_name.split('::').inject(Kernel) { |scope, const| scope.const_get(const, scope === Kernel) }
            end
          rescue NameError => e
            Chef::Log.debug(e)
            nil
          end
        end

        def self.version_klass(version)
          version = version.to_s unless version.kind_of?(String)
          if version.empty?
            # TODO create an exception class
            raise "Bad chef-encrypted-attribute version '#{version.inspect}'"
          end
          klass = string_to_klass("#{name.to_s}#{version}")
          if klass.nil?
            # TODO create an exception class
            raise "This version of chef-encrypted-attribute does not support encrypted attribute item format version '#{version}'"
          end
          klass
        end

      end # Version

      class Version0 < Version
        # TODO HMAC_ALGORITHM = 'sha256'

        def encrypt(value, public_keys)
          public_keys = remove_dup_keys(public_keys)
          self['_encrypted_rsa_data'] = Mash.new(Hash[
            public_keys.map do |public_key|
              [
                node_key(public_key),
                encrypt_value(public_key, json_encode(value)),
              ]
            end
          ])
          self
        end

        def decrypt(key)
          # TODO check input and enc_attr
          enc_value = self['_encrypted_rsa_data'][node_key(key.public_key)]
          json_decode(decrypt_value(key, enc_value))
          # we avoid saving the decrypted value, only return it
        end

        def can_be_decrypted_by?(keys)
          remove_dup_keys(keys).reduce(true) do |r, k|
            r and self['_encrypted_rsa_data'].kind_of?(Hash) and
              self['_encrypted_rsa_data'].has_key?(node_key(k))
          end
        end

        def needs_update?(keys)
          keys = remove_dup_keys(keys)
          not can_be_decrypted_by?(keys) && self['_encrypted_rsa_data'].keys.count == keys.count
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
