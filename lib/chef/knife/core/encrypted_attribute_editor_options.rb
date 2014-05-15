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

      module EncryptedAttributeEditorOptions
        def self.included(includer)
          includer.class_eval do

            deps do
              require 'chef/encrypted_attribute'
              require 'chef/json_compat'
            end

            option :encrypted_attribute_version,
              :long  => '--encrypted-attribute-version VERSION',
              :description => 'Encrypted Attribute protocol version to use',
              :proc => lambda { |i| Chef::Config[:knife][:encrypted_attributes][:version] = i }

            option :encrypted_attribute_partial_search,
              :long => '--disable-partial-search',
              :description => 'Disable partial search',
              :boolean => true,
              :proc => lambda { |i| Chef::Config[:knife][:encrypted_attributes][:partial_search] = false }

            option :encrypted_attribute_client_search,
              :short => '-C CLIENT_SEARCH_QUERY',
              :long => '--client-search CLIENT_SEARCH_QUERY',
              :description => 'Client search query',
              :proc => lambda { |i|
                Chef::Config[:knife][:encrypted_attributes][:client_search] = [] unless Chef::Config[:knife][:encrypted_attributes][:client_search].kind_of?(Array)
                Chef::Config[:knife][:encrypted_attributes][:client_search] << i
              }

            option :encrypted_attribute_users,
              :short => '-U USER',
              :long => '--encrypted-attribute-user USER',
              :description => 'User name to allow access to',
              :proc => lambda { |i|
                Chef::Config[:knife][:encrypted_attributes][:users] = [] unless Chef::Config[:knife][:encrypted_attributes][:users].kind_of?(Array)
                Chef::Config[:knife][:encrypted_attributes][:users] << i
              }

            # TODO option :keys

            # Modified Chef::Knife::UI#edit_data method with plain text format support
            def edit_data(data=nil, format='plain')
              output = case format
              when 'JSON', 'json'
                begin
                  data.nil? ? {} : Chef::JSONCompat.to_json_pretty(data)
                rescue JSON::GeneratorError
                  ui.warn('Previous data is not in JSON, it will be overwritten.')
                  sleep(2) # TODO a better pause/delay?
                  Chef::JSONCompat.to_json_pretty({})
                end
              else
                data.nil? ? '' : data
              end

              if !config[:disable_editing]
                Tempfile.open([ 'knife-edit-', '.json' ]) do |tf|
                  tf.sync = true
                  tf.puts output
                  tf.close
                  raise 'Please set EDITOR environment variable' unless system("#{config[:editor]} #{tf.path}")

                  output = IO.read(tf.path)
                  tf.unlink # not needed, but recommended
                end
              end

              case format
              when 'JSON', 'json'
                Chef::JSONCompat.from_json(output)
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
