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

require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/remote_clients'
require 'chef/encrypted_attribute/remote_users'
require 'chef/encrypted_attribute/attribute_body/version'
require 'chef/encrypted_attribute/attribute_body/version0'
require 'chef/encrypted_attribute/attribute_body/version1'

class Chef
  class EncryptedAttribute
    class AttributeBody

      def initialize(c=nil)
        config(Config.new(c))
      end

      def config(arg=nil)
        unless arg.nil?
          @config = Config.new(arg)
        else
          @config
        end
      end

      # Decrypts an encrypted attribute from a (encrypted) Hash
      def load(enc_hs)
        body = AttributeBody::Version.json_create(enc_hs)
        local_node = LocalNode.new
        body.decrypt(local_node.key)
      end

      # Decrypts a encrypted attribute from a remote node
      def load_from_node(name, attr_ary)
        remote_node = RemoteNode.new(name)
        self.load(remote_node.load_attribute(attr_ary, config.partial_search))
      end

      # Creates an encrypted attribute from a Hash
      def create(hs)
        body = AttributeBody::Version.create(config.version)
        body.encrypt(hs, target_keys)
      end

      # Updates the keys for which the attribute is encrypted
      def update(enc_hs)
        old_body = AttributeBody::Version.json_create(enc_hs)
        if old_body.needs_update?(target_keys)
          hs = old_body.decrypt(local_node.key)
          new_body = create(hs)
          enc_hs.replace(new_body)
          true
        else
          false
        end
      end

      def self.exists?(enc_hs)
        AttributeBody::Version.exists?(enc_hs)
      end

      protected

      def local_node
        @local_node ||= LocalNode.new
      end

      def target_keys
        @target_keys ||= begin
          remote_keys = RemoteClients.get_public_keys(config.client_search, config.partial_search)
          keys = remote_keys + config.keys
          keys.push(local_node.public_key)
          keys
        end # TODO improve this cache, can be problematic
      end

    end
  end
end
