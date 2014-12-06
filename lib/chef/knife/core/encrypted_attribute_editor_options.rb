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

require 'chef/knife/core/config'

class Chef
  class Knife
    module Core
      # Reads knife encrypted attribute edit commands arguments
      module EncryptedAttributeEditorOptions
        def self.included(includer)
          includer.class_eval do

            def self.encrypted_attributes_option_set(key, value)
              Chef::Config[:knife][:encrypted_attributes][key] = value
            end

            def self.encrypted_attributes_option_push(key, value)
              unless Chef::Config[:knife][:encrypted_attributes][key]
                     .is_a?(Array)
                Chef::Config[:knife][:encrypted_attributes][key] = []
              end
              Chef::Config[:knife][:encrypted_attributes][key] << value
            end

            option :encrypted_attribute_version,
                   long: '--encrypted-attribute-version VERSION',
                   description: 'Encrypted Attribute protocol version to use',
                   proc: ->(i) { encrypted_attributes_option_set(:version, i) }

            option :encrypted_attribute_partial_search,
                   short: '-P',
                   long: '--disable-partial-search',
                   description: 'Disable partial search',
                   boolean: true,
                   proc:
                    (lambda do |_i|
                      encrypted_attributes_option_set(:partial_search, false)
                    end)

            option :encrypted_attribute_client_search,
                   short: '-C CLIENT_SEARCH_QUERY',
                   long: '--client-search CLIENT_SEARCH_QUERY',
                   description:
                     'Client search query. Can be specified multiple times',
                   proc:
                     (lambda do |i|
                       encrypted_attributes_option_push(:client_search, i)
                     end)

            option :encrypted_attribute_node_search,
                   short: '-N NODE_SEARCH_QUERY',
                   long: '--node-search NODE_SEARCH_QUERY',
                   description:
                     'Node search query. Can be specified multiple times',
                   proc:
                     ->(i) { encrypted_attributes_option_push(:node_search, i) }

            option :encrypted_attribute_users,
                   short: '-U USER',
                   long: '--encrypted-attribute-user USER',
                   description:
                     'User name to allow access to. Can be specified multiple '\
                     'times',
                   proc: ->(i) { encrypted_attributes_option_push(:users, i) }

            # TODO: option :keys

            # Modified Chef::Knife::UI#edit_data method with plain text format
            # support

            def edit_data_string_to_obj(data, format)
              case format
              when 'JSON', 'json'
                if data.nil?
                  {}
                else
                  Chef::JSONCompat.to_json_pretty(data, quirks_mode: true)
                end
              else
                data.nil? ? '' : data
              end
            end

            def edit_data_obj_to_string(data, format)
              case format
              when 'JSON', 'json'
                FFI_Yajl::Parser.parse(data)
              else
                data
              end
            end

            def edit_data_run_editor_command(path)
              return if system("#{config[:editor]} #{path}")
              fail 'Please set EDITOR environment variable'
            end

            def edit_data_run_editor(data)
              return if config[:disable_editing]
              result = nil
              Tempfile.open(%w(knife-edit- .json)) do |tf|
                tf.sync = true
                tf.puts(data)
                tf.close
                edit_data_run_editor_command(tf.path)
                result = IO.read(tf.path)
              end
              result
            end

            def edit_data(data = nil, format = 'plain')
              output = edit_data_string_to_obj(data, format)
              output = edit_data_run_editor(output)
              edit_data_obj_to_string(output, format)
            end # def edit_data

          end # includer.class_eval
        end # self.included(includer)
      end # EncryptedAttributeEditorOptions
    end # Core
  end # Knife
end # Chef
