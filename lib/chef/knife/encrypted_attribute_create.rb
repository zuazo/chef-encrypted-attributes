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
require 'chef/knife/core/encrypted_attribute_editor_options'

class Chef
  class Knife
    # knife encrypted attribute create command
    class EncryptedAttributeCreate < EncryptedAttributeBase
      include Knife::Core::EncryptedAttributeEditorOptions

      option :input_format,
             short: '-i FORMAT',
             long: '--input-format FORMAT',
             description:
                'Input (EDITOR) format, supported formats are "plain" '\
                '(default) and "json"'

      banner 'knife encrypted attribute create NODE ATTRIBUTE (options)'

      def assert_valid_args
        # check if the encrypted attribute already exists
        assert_attribute_does_not_exist(@node_name, @attr_ary)
      end

      def run
        parse_args

        # create encrypted attribute
        output = edit_data(nil, config[:input_format])
        enc_attr =
          Chef::EncryptedAttribute.new(
            Chef::Config[:knife][:encrypted_attributes]
          )
        enc_attr.create_on_node(@node_name, @attr_ary, output)
      end
    end
  end
end
