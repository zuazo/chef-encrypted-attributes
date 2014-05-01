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

class Chef
  class Knife
    class EncryptedAttributeCreate < EncryptedAttributeShow

      deps do
        require 'chef/encrypted_attribute'
        require 'chef/json_compat'
      end

      option :encrypted_attribute_version,
        :long  => '--encrypted-attribute-version VERSION',
        :description => 'Encrypted Attribute protocol version to use',
        :proc => lambda { |i| Chef::Config[:encrypted_attributes][:version] = i }

      option :encrypted_attribute_partial_search,
        :long => '--disable-partial-search',
        :description => 'Disable partial search',
        :boolean => true,
        :proc => lambda { |i| Chef::Config[:encrypted_attributes][:partial_search] = false }

      Chef::Config[:encrypted_attributes][:client_search] = []
      option :encrypted_attribute_client_search,
        :short => '-C CLIENT_SEARCH_QUERY',
        :long => '--client-search CLIENT_SEARCH_QUERY',
        :description => 'Client search query',
        :proc => lambda { |i| Chef::Config[:encrypted_attributes][:client_search] << i }

      Chef::Config[:encrypted_attributes][:users] = []
      option :encrypted_attribute_users,
        :short => '-U USER',
        :long => '--encrypted-attribute-user USER',
        :description => 'User name to allow access to',
        :proc => lambda { |i| Chef::Config[:encrypted_attributes][:users] << i }

      option :input_format,
        :short => '-i FORMAT',
        :long => '--input-format FORMAT',
        :description => 'Input (EDITOR) format, supported formats are "plain" (default) and "json"'

      # TODO option :keys

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
        enc_attr = enc_attr.create_on_node(node_name, attr_ary, output)
      end

      # Modified Chef::Knife::UI#edit_data method with plain text format support
      def edit_data(data=nil, format='plain')
        output = case format
        when 'JSON', 'json'
          data.nil? ? {} : Chef::JSONCompat.to_json_pretty(data)
        else
          data.nil? ? '' : data
        end

        if (!config[:disable_editing])
          Tempfile.open([ 'knife-edit-', '.json' ]) do |tf|
            tf.sync = true
            tf.puts output
            tf.close
            raise 'Please set EDITOR environment variable' unless system("#{config[:editor]} #{tf.path}")

            output = IO.read(tf.path)
          end
        end

        case format
        when 'JSON', 'json'
          Chef::JSONCompat.from_json(output)
        else
          output
        end
      end

    end
  end
end
