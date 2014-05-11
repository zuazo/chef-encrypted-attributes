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

require 'chef/knife'
require 'chef/knife/encrypted_attribute_show'
require 'chef/encrypted_attribute/remote_node'

class Chef
  class Knife
    class EncryptedAttributeDelete < EncryptedAttributeShow

      deps do
        require 'chef/encrypted_attribute'
        require 'chef/json_compat'
      end

      banner 'knife encrypted attribute delete NODE ATTRIBUTE (options)'

      option :force,
        :long => '--force',
        :description => 'Force the attribute deletion even if you cannot read it',
        :boolean => true

      def run
        node_name = @name_args[0]
        attr_path = @name_args[1]

        if node_name.nil?
          show_usage
          ui.fatal('You must specify a node name')
          exit 1
        end

        if attr_path.nil?
          show_usage
          ui.fatal('You must specify an encrypted attribute name')
          exit 1
        end

        attr_ary = attribute_path_to_ary(attr_path)
        if Chef::EncryptedAttribute.exists_on_node?(node_name, attr_ary)
          # TODO move this to lib/EncryptedAttribute
          unless config[:force] # try to read the attribute
            Chef::EncryptedAttribute.load_from_node(node_name, attr_ary)
          end
          remote_node = Chef::EncryptedAttribute::RemoteNode.new(node_name)
          if remote_node.delete_attribute(attr_ary)
            ui.info('Encrypted attribute deleted.')
          end
        end
      end

    end
  end
end
