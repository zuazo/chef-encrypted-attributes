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

class Chef
  class Knife
    class EncryptedAttributeShow < Knife

      deps do
        require 'chef/encrypted_attribute'
        require 'chef/json_compat'
      end

      banner 'knife encrypted attribute NODE ATTRIBUTE (options)'

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

        enc_attr = Chef::EncryptedAttribute.load_from_node(node_name, attribute_path_to_ary(attr_path))
        output(enc_attr)
      end

      def attribute_path_to_ary(str, delim='.', escape='\\')
        # return str.scan(/(?:[^.\\]|\\.)+/).map {|x| x.gsub('\\.', '.') } # cool, but doesn't work for some edge cases
        result = []
        current = ''
        i = 0
        while ! str[i].nil?
          if str[i] == escape
            if str[i+1] == delim
              current << str[i+1]
            else
              current << str[i]
              current << str[i+1] unless str[i+1].nil?
            end
            i += 1 # skip the next char
          elsif str[i] == delim
            result << current
            current = ''
          else
            current << str[i]
          end
          i += 1
        end
        result << current
      end

    end
  end
end
