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

require 'chef/knife/core/encrypted_attribute_base'
require 'chef/knife/core/encrypted_attribute_depends'
require 'chef/encrypted_attribute/remote_node'

class Chef
  class Knife
    # knife encrypted attribute delete command.
    #
    # ```
    # $ knife encrypted attribute delete NODE ATTRIBUTE (options)
    # ```
    class EncryptedAttributeDelete < Core::EncryptedAttributeBase
      include Knife::Core::EncryptedAttributeDepends

      banner 'knife encrypted attribute delete NODE ATTRIBUTE (options)'

      option :force,
             short: '-f',
             long: '--force',
             description:
               'Force the attribute deletion even if you cannot read it',
             boolean: true

      # Runs knife command.
      def run
        parse_args

        return unless
          Chef::EncryptedAttribute.exist_on_node?(@node_name, @attr_ary)
        # TODO: move this to lib/EncryptedAttribute
        assert_attribute_readable(@node_name, @attr_ary) unless config[:force]
        remote_node = Chef::EncryptedAttribute::RemoteNode.new(@node_name)
        return unless remote_node.delete_attribute(@attr_ary)
        ui.info('Encrypted attribute deleted.')
      end
    end
  end
end
