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

            deps do
              require 'chef/encrypted_attribute'
              require 'chef/json_compat'
            end

            def self.encrypted_attributes_config
              Chef::Config[:knife][:encrypted_attributes]
            end

            option :encrypted_attribute_version,
                   long: '--encrypted-attribute-version VERSION',
                   description: 'Encrypted Attribute protocol version to use',
                   proc: ->(i) { encrypted_attributes_config[:version] = i }

            option :encrypted_attribute_partial_search,
                   short: '-P',
                   long: '--disable-partial-search',
                   description: 'Disable partial search',
                   boolean: true,
                   proc:
                    (lambda do |_i|
                      encrypted_attributes_config[:partial_search] = false
                    end)

            option :encrypted_attribute_client_search,
                   short: '-C CLIENT_SEARCH_QUERY',
                   long: '--client-search CLIENT_SEARCH_QUERY',
                   description:
                     'Client search query. Can be specified multiple times',
                   proc:
                     (lambda do |i|
                       unless encrypted_attributes_config[:client_search]
                              .is_a?(Array)
                         encrypted_attributes_config[:client_search] = []
                       end
                       encrypted_attributes_config[:client_search] << i
                     end)

            option :encrypted_attribute_node_search,
                   short: '-N NODE_SEARCH_QUERY',
                   long: '--node-search NODE_SEARCH_QUERY',
                   description:
                     'Node search query. Can be specified multiple times',
                   proc:
                     (lambda do |i|
                       unless encrypted_attributes_config[:node_search]
                              .is_a?(Array)
                         encrypted_attributes_config[:node_search] = []
                       end
                       encrypted_attributes_config[:node_search] << i
                     end)

            option :encrypted_attribute_users,
                   short: '-U USER',
                   long: '--encrypted-attribute-user USER',
                   description:
                     'User name to allow access to. Can be specified multiple '\
                     'times',
                   proc:
                     (lambda do |i|
                       unless encrypted_attributes_config[:users].is_a?(Array)
                         encrypted_attributes_config[:users] = []
                       end
                       encrypted_attributes_config[:users] << i
                     end)

            # TODO: option :keys

            # Modified Chef::Knife::UI#edit_data method with plain text format
            # support
            def edit_data(data = nil, format = 'plain')
              output =
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

              unless config[:disable_editing]
                Tempfile.open(%w(knife-edit- .json)) do |tf|
                  tf.sync = true
                  tf.puts output
                  tf.close
                  unless system("#{config[:editor]} #{tf.path}")
                    fail 'Please set EDITOR environment variable'
                  end

                  output = IO.read(tf.path)
                  tf.unlink # not needed, but recommended
                end
              end

              case format
              when 'JSON', 'json'
                FFI_Yajl::Parser.parse(output)
              else
                output
              end
            end # def edit_data

          end # includer.class_eval
        end # self.included(includer)
      end # EncryptedAttributeEditorOptions
    end # Core
  end # Knife
end # Chef
