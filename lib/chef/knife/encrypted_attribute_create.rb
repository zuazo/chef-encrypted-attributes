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

require 'chef/knife/encrypted_attribute_show'
require 'chef/knife/core/encrypted_attribute_editor_options'

class Chef
  class Knife
    class EncryptedAttributeCreate < EncryptedAttributeShow

      include Knife::Core::EncryptedAttributeEditorOptions

      option :input_format,
        :short => '-i FORMAT',
        :long => '--input-format FORMAT',
        :description => 'Input (EDITOR) format, supported formats are "plain" (default) and "json"'

      banner 'knife encrypted attribute create NODE ATTRIBUTE (options)'

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

        # check if the encrypted attribute already exists
        if Chef::EncryptedAttribute.exists_on_node?(node_name, attr_ary)
          ui.fatal('Encrypted attribute already exists')
          exit 1
        end

        # create encrypted attribute
        output = edit_data(nil, config[:input_format])
        enc_attr = Chef::EncryptedAttribute.new
        enc_attr.create_on_node(node_name, attr_ary, output)
      end

    end
  end
end
