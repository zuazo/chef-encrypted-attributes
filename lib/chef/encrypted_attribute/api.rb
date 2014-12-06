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

require 'chef/encrypted_attribute/config'
require 'chef/encrypted_attribute/encrypted_mash'
require 'chef/config'

require 'chef/encrypted_attribute/local_node'
require 'chef/encrypted_attribute/remote_node'
require 'chef/encrypted_attribute/encrypted_mash/version0'
require 'chef/encrypted_attribute/encrypted_mash/version1'
require 'chef/encrypted_attribute/encrypted_mash/version2'

class Chef
  class EncryptedAttribute
    # Main EncryptedAttribute class methods API module
    module API
      def debug(msg)
        Chef::Log.debug("Chef::EncryptedAttribute: #{msg}")
      end

      def warn(msg)
        Chef::Log.warn(msg)
      end

      def local_node
        LocalNode.new
      end

      def config(arg)
        config =
          EncryptedAttribute::Config.new(Chef::Config[:encrypted_attributes])
        config.update!(arg)
        config.keys(config.keys + [local_node.public_key])
        config
      end

      # public

      def load(hs, c = {})
        debug("Loading Local Encrypted Attribute from: #{hs.inspect}")
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.load(hs)
        debug('Local Encrypted Attribute loaded.')
        result
      end

      def load_from_node(name, attr_ary, c = {})
        debug(
          "Loading Remote Encrypted Attribute from #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.load_from_node(name, attr_ary)
        debug('Remote Encrypted Attribute loaded.')
        result
      end

      def create(value, c = {})
        debug('Creating Encrypted Attribute.')
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.create(value)
        debug('Encrypted Attribute created.')
        result
      end

      def create_on_node(name, attr_ary, value, c = {})
        debug(
          "Creating Remote Encrypted Attribute on #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.create_on_node(name, attr_ary, value)
        debug('Encrypted Remote Attribute created.')
        result
      end

      def update(hs, c = {})
        debug("Updating Encrypted Attribute: #{hs.inspect}")
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.update(hs)
        if result
          debug('Encrypted Attribute updated.')
        else
          debug('Encrypted Attribute not updated.')
        end
        result
      end

      def update_on_node(name, attr_ary, c = {})
        debug(
          "Updating Remote Encrypted Attribute on #{name}: #{attr_ary.inspect}"
        )
        enc_attr = EncryptedAttribute.new(config(c))
        result = enc_attr.update_on_node(name, attr_ary)
        debug("Encrypted Remote Attribute #{result ? '' : 'not '}updated.")
        result
      end

      def exist?(hs)
        debug("Checking if Encrypted Attribute exists here: #{hs.inspect}")
        result = EncryptedMash.exist?(hs)
        debug("Encrypted Attribute #{result ? '' : 'not '}found.")
        result
      end

      def exists?(*args)
        warn("#{name}.exists? is deprecated in favor of #{name}.exist?.")
        exist?(*args)
      end

      def exist_on_node?(name, attr_ary, c = {})
        debug("Checking if Remote Encrypted Attribute exists on #{name}")
        remote_node = RemoteNode.new(name)
        node_attr =
          remote_node.load_attribute(attr_ary, config(c).partial_search)
        Chef::EncryptedAttribute.exist?(node_attr)
      end

      def exists_on_node?(*args)
        warn(
          "#{name}.exists_on_node? is deprecated in favor of "\
          "#{name}.exist_on_node?."
        )
        exist_on_node?(*args)
      end
    end
  end
end
