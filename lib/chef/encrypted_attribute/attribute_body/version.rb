class Chef
  class EncryptedAttribute
    class AttributeBody
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

      end
    end
  end
end
