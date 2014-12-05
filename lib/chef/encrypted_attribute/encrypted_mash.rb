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

require 'chef/mash'
require 'chef/encrypted_attribute/exceptions'

class Chef
  class EncryptedAttribute
    # Mash structure with embedded Mash structure encrypted. This class is
    # oriented to be easily integrable with chef in the future using JSONCompat
    class EncryptedMash < Mash
      JSON_CLASS =      'x_json_class'.freeze
      CHEF_TYPE =       'chef_type'.freeze
      CHEF_TYPE_VALUE = 'encrypted_attribute'.freeze

      VERSION_PREFIX = "#{name}::Version"

      def initialize(enc_hs = nil)
        super
        self[JSON_CLASS] = self.class.name
        self[CHEF_TYPE] = CHEF_TYPE_VALUE
        update_from!(enc_hs) if enc_hs.is_a?(Hash)
      end

      %w(encrypt decrypt can_be_decrypted_by? needs_update?).each do |meth|
        define_method(meth) do
          fail NotImplementedError,
               "#{self.class}##{__method__} method not implemented."
        end
      end

      def self.exist?(enc_hs)
        enc_hs.is_a?(Hash) &&
          enc_hs.key?(JSON_CLASS) &&
          enc_hs[JSON_CLASS] =~ /^#{Regexp.escape(Module.nesting[1].name)}/ &&
          enc_hs.key?(CHEF_TYPE) && enc_hs[CHEF_TYPE] == CHEF_TYPE_VALUE
      end

      def self.exists?(*args)
        Chef::Log.warn(
          "#{name}.exists? is deprecated in favor of #{name}.exist?."
        )
        exist?(*args)
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
      def for_json
        to_hash
      end

      # Update the EncryptedMash from Hash
      def update_from!(enc_hs)
        unless self.class.exist?(enc_hs)
          fail UnacceptableEncryptedAttributeFormat,
               'Trying to construct invalid encrypted attribute. Maybe it is '\
               'not encrypted?'
        end
        enc_hs = enc_hs.dup
        enc_hs.delete(JSON_CLASS)
        enc_hs.delete(CHEF_TYPE)
        update(enc_hs)
      end

      # Create an EncryptedMash::Version from JSON Hash
      def self.json_create(enc_hs)
        klass = string_to_klass(enc_hs[JSON_CLASS])
        if klass.nil?
          fail UnsupportedEncryptedAttributeFormat,
               "Unknown chef-encrypted-attribute class #{enc_hs[JSON_CLASS]}"
        end
        klass.send(:new, enc_hs)
      end

      # protected

      def self.string_to_klass(class_name)
        unless class_name.is_a?(String)
          fail UnacceptableEncryptedAttributeFormat,
               "Bad chef-encrypted-attribute class name #{class_name.inspect}"
        end
        begin
          class_name.split('::').inject(Kernel) do |scope, const|
            scope.const_get(const, scope == Kernel)
          end
        rescue NameError => e
          Chef::Log.error(e)
          nil
        end
      end

      def self.version_klass(version)
        version = version.to_s unless version.is_a?(String)
        if version.empty?
          fail UnacceptableEncryptedAttributeFormat,
               "Bad chef-encrypted-attribute version #{version.inspect}"
        end
        klass = string_to_klass("#{VERSION_PREFIX}#{version}")
        if klass.nil?
          fail UnsupportedEncryptedAttributeFormat,
               'This version of chef-encrypted-attribute does not support '\
               "encrypted attribute item format version: \"#{version}\""
        end
        klass
      end
    end
  end
end
