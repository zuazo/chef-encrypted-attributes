#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL. (www.onddo.com)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    class AttributeBody
      class Version < Mash

        # This class is oriented to be easily integrable with
        # chef in the future using JSONCompat

        JSON_CLASS =      'x_json_class'.freeze
        CHEF_TYPE =       'x_chef_type'.freeze # TODO "x_" not needed here?
        CHEF_TYPE_VALUE = 'encrypted_attribute'.freeze

        def initialize(enc_hs=nil)
          super
          self[JSON_CLASS] = self.class.name
          self[CHEF_TYPE] = CHEF_TYPE_VALUE
          update_from!(enc_hs) if enc_hs.kind_of?(Hash)
        end

        %w{encrypt decrypt can_be_decrypted_by? needs_update?}.each do |meth|
          define_method(meth) do
            raise NotImplementedError, "#{self.class.to_s}##{__method__} method not implemented."
          end
        end

        def self.exists?(enc_hs)
          enc_hs.kind_of?(Hash) and
          enc_hs.has_key?(JSON_CLASS) and
          enc_hs[JSON_CLASS] =~ /^#{Regexp.escape(Module.nesting[1].name)}/ and
          enc_hs.has_key?(CHEF_TYPE) and enc_hs[CHEF_TYPE] == CHEF_TYPE_VALUE
        end

        def self.create(version)
          klass = version_klass(version)
          klass.send(:new)
        end

        # Serialize this object as a Hash
        def to_json(*a)
          for_json.to_json(*a)
        end

        # Returns a Hash for JSON
        # TODO not needed method?
        def for_json
          to_hash
        end

        # Update the AttributeBody from Hash
        def update_from!(enc_hs)
          unless self.class.exists?(enc_hs)
            raise UnacceptableEncryptedAttributeFormat, 'Trying to construct invalid encrypted attribute. Maybe it is not encrypted?'
          end
          enc_hs = enc_hs.dup
          enc_hs.delete(JSON_CLASS)
          enc_hs.delete(CHEF_TYPE)
          update(enc_hs)
        end

        # Create an AttributeBody::Version from JSON Hash
        def self.json_create(enc_hs)
          klass = string_to_klass(enc_hs[JSON_CLASS])
          if klass.nil?
            raise UnsupportedEncryptedAttributeFormat, "Unknown chef-encrypted-attribute class \"#{enc_hs[JSON_CLASS]}\""
          end
          klass.send(:new, enc_hs)
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
            Chef::Log.info(e)
            nil
          end
        end

        def self.version_klass(version)
          version = version.to_s unless version.kind_of?(String)
          if version.empty?
            raise UnacceptableEncryptedAttributeFormat, "Bad chef-encrypted-attribute version \"#{version.inspect}\""
          end
          klass = string_to_klass("#{name.to_s}#{version}")
          if klass.nil?
            raise UnsupportedEncryptedAttributeFormat, "This version of chef-encrypted-attribute does not support encrypted attribute item format version: \"#{version}\""
          end
          klass
        end

      end
    end
  end
end
