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
require 'chef/encrypted_attribute/encrypted_mash/base'
require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'

# EncryptedMash Factory class for EncryptedMash::Version* classes
class Chef
  class EncryptedAttribute
    class EncryptedMash

      def initialize(c=nil)
        config(c)
      end

      def config(arg=nil)
        unless arg.nil?
          @config = Config.new(arg)
          @config.keys.push(local_node.public_key)
        else
          @config
        end
      end

      # Decrypts an encrypted attribute from a (encrypted) Hash
      def load(enc_hs)
        body = EncryptedMash::Base.json_create(enc_hs)
        body.decrypt(local_node.key)
      end

      # Decrypts a encrypted attribute from a remote node
      def load_from_node(name, attr_ary)
        remote_node = RemoteNode.new(name)
        self.load(remote_node.load_attribute(attr_ary, config.partial_search))
      end

      # Creates an encrypted attribute from a Hash
      def create(hs)
        body = EncryptedMash::Base.create(config.version)
        body.encrypt(hs, config.keys + remote_client_keys)
      end

      # Updates the keys for which the attribute is encrypted
      def update(enc_hs)
        old_body = EncryptedMash::Base.json_create(enc_hs)
        if old_body.needs_update?(config.keys + remote_client_keys)
          hs = old_body.decrypt(local_node.key)
          new_body = create(hs)
          enc_hs.replace(new_body)
          true
        else
          false
        end
      end

      def self.exists?(enc_hs)
        EncryptedMash::Base.exists?(enc_hs)
      end

      protected

      def local_node
        @local_node ||= LocalNode.new
      end

      def remote_client_keys
        RemoteClients.get_public_keys(config.client_search, config.partial_search)
      end

    end
  end
end
