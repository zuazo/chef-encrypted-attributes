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
    module Core
      # knife encrypted attribute commands base class.
      #
      # All encrypted attribute knife commands inherit some common method from
      # this class.
      class EncryptedAttributeBase < Knife
        # Prints a fatal error and exits without success.
        #
        # @param msg [String] message to print.
        # @return void
        def die(msg)
          ui.fatal(msg)
          exit 1
        end

        # Asserts that the option value is not `nil`.
        #
        # Shows usage and exists if `nil`.
        #
        # @param option [Mixed] value to check.
        # @param msg [String] error message to print in case value is `nil`.
        # @return void
        def option_assert(option, msg)
          return unless option.nil?
          show_usage
          die(msg)
        end

        # Asserts that an encrypted attribute exists.
        #
        # Exits with error if the attribute does no exist.
        #
        # @param node_name [String] Chef node name.
        # @param attr_ary [Array<String>] node attribute path as Array.
        # @return void
        def assert_attribute_exists(node_name, attr_ary)
          return if Chef::EncryptedAttribute.exist_on_node?(node_name, attr_ary)
          die('Encrypted attribute not found')
        end

        # Asserts that an encrypted attribute does not exist.
        #
        # Exits with error if the attribute exist.
        #
        # @param node_name [String] Chef node name.
        # @param attr_ary [Array<String>] node attribute path as Array.
        # @return void
        def assert_attribute_does_not_exist(node_name, attr_ary)
          return unless
            Chef::EncryptedAttribute.exist_on_node?(node_name, attr_ary)
          die('Encrypted attribute already exists')
        end

        # Parse knife arguments.
        #
        # Exits with error if the arguments are wrong.
        #
        # @return void
        # @see #assert_valid_args
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

        # Asserts that the arguments are valid.
        #
        # Exits with error if arguments are wrong.
        #
        # @return void
        def assert_valid_args
          # nop
        end

        # Asserts that I can decrypt an encrypted attribute from a remote node.
        #
        # Exists with an error if the attribute cannot be decrypted.
        #
        # @param node_name [String] Chef node name.
        # @param attr_ary [Array<String>] node attribute path as Array.
        # @return void
        def assert_attribute_readable(node_name, attr_ary)
          # try to read the attribute
          Chef::EncryptedAttribute.load_from_node(node_name, attr_ary)
        end

        # @api private
        def attribute_path_to_ary_read_escape(str, i, delim)
          if str[i + 1] == delim
            str[i + 1]
          else
            str[i] + (str[i + 1].nil? ? '' : str[i + 1])
          end
        end

        # Parses an array path in or escaped string notation.
        #
        # Literal delimiter values can be escaped using the escape character.
        #
        # Uses dot notation by default, using `'.'` as delimiter and `'\'` as
        # escape character.
        #
        # For example, for `'encrypted.attr\.ibute'` will return
        # `%w(encrypted attr.ibute)`.
        #
        # @param str [String] array path in dot notation.
        # @param delim [String] delimiter used for string notation.
        # @param escape [String] escape character to use.
        # @return [Array<String>] attribute path as array.
        def attribute_path_to_ary(str, delim = '.', escape = '\\')
          # cool, but doesn't work for some edge cases
          # return str.scan(/(?:[^.\\]|\\.)+/).map {|x| x.gsub('\\.', '.') }
          result = []
          current = ''
          i = 0
          until str[i].nil?
            if str[i] == escape
              current << attribute_path_to_ary_read_escape(str, i, delim)
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
end
