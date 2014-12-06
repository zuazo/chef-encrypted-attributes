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
    # knife encrypted attribute show command
    class EncryptedAttributeBase < Knife
      deps do
        require 'chef/encrypted_attribute'
        require 'chef/json_compat'
      end

      def die(msg)
        ui.fatal(msg)
        exit 1
      end

      def option_assert(option, msg)
        return unless option.nil?
        show_usage
        die(msg)
      end

      def assert_attribute_exists(node_name, attr_ary)
        return if Chef::EncryptedAttribute.exist_on_node?(node_name, attr_ary)
        die('Encrypted attribute not found')
      end

      def assert_attribute_does_not_exist(node_name, attr_ary)
        return unless
          Chef::EncryptedAttribute.exist_on_node?(node_name, attr_ary)
        die('Encrypted attribute already exists')
      end

      def parse_args
        @node_name = @name_args[0]
        @attr_path = @name_args[1]
        option_assert(@node_name, 'You must specify a node name')
        option_assert(
          @attr_path, 'You must specify an encrypted attribute name'
        )
        @attr_ary = attribute_path_to_ary(@attr_path)

        assert_valid_args
      end

      def assert_valid_args
        # nop
      end

      def assert_attribute_readable(node_name, attr_ary)
        # try to read the attribute
        Chef::EncryptedAttribute.load_from_node(node_name, attr_ary)
      end

      def attribute_path_to_ary(str, delim = '.', escape = '\\')
        # cool, but doesn't work for some edge cases
        # return str.scan(/(?:[^.\\]|\\.)+/).map {|x| x.gsub('\\.', '.') }
        result = []
        current = ''
        i = 0
        until str[i].nil?
          if str[i] == escape
            if str[i + 1] == delim
              current << str[i + 1]
            else
              current << str[i]
              current << str[i + 1] unless str[i + 1].nil?
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
