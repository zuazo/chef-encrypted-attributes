# encoding: UTF-8
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
    # Mash structure with embedded Mash structure encrypted.
    #
    # This is the most basic encrypted object, which inherits from `Chef::Mash`.
    #
    # This class is used to construct the different EncryptedAttribute versions.
    # Each version implements the encryption in a different way or using
    # different algorithms.
    #
    # Currently three {EncryptedMash} versions exists. But you can create your
    # own versions and name it with the
    # `Chef::EncryptedAttribute::EncryptedMash::Version` prefix.
    #
    # Uses {EncryptedMash::Version1} by default.
    #
    # This class is oriented to be easily integrable with chef in the future
    # using `JSONCompat`.
    #
    # @see .create
    # @see EncryptedMash::Version0
    # @see EncryptedMash::Version1
    # @see EncryptedMash::Version2
    class EncryptedMash < Mash
      # Mash key name to use for JSON class name. Chef uses the `'json_class'`
      # key internally for objects, we use a renamed key.
      JSON_CLASS =      'x_json_class'.freeze

      # Mash key name to use for Chef object type.
      CHEF_TYPE =       'chef_type'.freeze

      # Chef object type value.
      CHEF_TYPE_VALUE = 'encrypted_attribute'.freeze

      # Name prefix for all  EncryptedAttribute version classes.
      # Used internally by the #self.version_class method.
      # @api private
      VERSION_PREFIX = "#{name}::Version"

      # Encrypted Mash constructor.
      #
      # @param enc_hs [Mash] encrypted Mash to clone.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   format is wrong or does not exist.
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

      # Checks whether an encrypted Mash exists.
      #
      # @param enc_hs [Mash] Mash to check.
      # @return [Boolean] returns `true` if an encrypted Mash exists.
      def self.exist?(enc_hs)
        enc_hs.is_a?(Hash) &&
          enc_hs.key?(JSON_CLASS) &&
          enc_hs[JSON_CLASS] =~ /^#{Regexp.escape(Module.nesting[1].name)}/ &&
          enc_hs.key?(CHEF_TYPE) && enc_hs[CHEF_TYPE] == CHEF_TYPE_VALUE
      end

      # Checks whether an encrypted Mash exists.
      #
      # @param args [Mash] {exist?} arguments.
      # @return [Boolean] returns `true` if an encrypted Mash exists.
      # @deprecated Use {exist?} instead.
      def self.exists?(*args)
        Chef::Log.warn(
          "#{name}.exists? is deprecated in favor of #{name}.exist?."
        )
        exist?(*args)
      end

      # Factory method to construct an encrypted Mash.
      #
      # @param version [String, Fixnum] EncryptedMash version to use.
      # @raise [RequirementsFailure] if the specified encrypted attribute
      #   version cannot be used.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   format is wrong.
      # @raise [UnsupportedEncryptedAttributeFormat] if encrypted attribute
      #   format is not supported or unknown.
      def self.create(version)
        klass = version_klass(version)
        klass.send(:new)
      end

      # Serializes this object as a Hash.
      #
      # @param a [Hash] Ruby _#to_json_ call arguments.
      # @return [String] JSON representation of the object.
      def to_json(*a)
        for_json.to_json(*a)
      end

      # Returns the object as a Ruby Hash.
      #
      # @return [Hash] ruby Hash represtation of the object.
      def for_json
        to_hash
      end

      # Replaces the EncryptedMash content from a Mash.
      #
      # @param enc_hs [Mash] Mash to clone.
      # @return [Mash] `self`.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   format is wrong or does not exist.
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

      # Creates an *EncryptedMash::Version* object from a JSON Hash.
      #
      # Reads the EncryptedMash version to create from the {JSON_CLASS} key.
      #
      # @param enc_hs [Mash] Encrypted Mash as a Mash. As it is read from node
      #   attributes.
      # @return [EncryptedMash] *EncryptedMash::Version* object.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   format is wrong.
      # @raise [UnsupportedEncryptedAttributeFormat] if encrypted attribute
      #   format is not supported or unknown.
      def self.json_create(enc_hs)
        klass = string_to_klass(enc_hs[JSON_CLASS])
        if klass.nil?
          fail UnsupportedEncryptedAttributeFormat,
               "Unknown chef-encrypted-attribute class #{enc_hs[JSON_CLASS]}"
        end
        klass.send(:new, enc_hs)
      end

      # Gets the class reference from its string representation.
      #
      # @param class_name [String] the class name as string.
      # @return [Class] the class reference.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   class name is wrong.
      # @api private
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

      # Gets the class reference for a EncryptedMash version.
      #
      # The implementation of `"Chef::EncryptedAttribute::Version#{version}"`
      # must exists and be included (`require`) beforehand.
      #
      # @param version [String, Fixnum] the EncryptedMash version.
      # @return [Class] the EncryptedMash version class reference.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   version is wrong.
      # @raise [UnsupportedEncryptedAttributeFormat] if encrypted attribute
      #   format is not supported or unknown.
      # @api private
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
