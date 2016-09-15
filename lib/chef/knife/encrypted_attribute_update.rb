# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
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
require 'chef/knife/core/encrypted_attribute_editor_options'

class Chef
  class Knife
    # knife encrypted attribute update command.
    #
    # ```
    # $ knife encrypted attribute update NODE ATTRIBUTE (options)
    # ```
    class EncryptedAttributeUpdate < Core::EncryptedAttributeBase
      include Knife::Core::EncryptedAttributeDepends
      include Knife::Core::EncryptedAttributeEditorOptions

      banner 'knife encrypted attribute update NODE ATTRIBUTE (options)'

      # (see EncryptedAttributeBase#assert_valid_args)
      # @raise [ArgumentError] if the attribute path format is wrong.
      def assert_valid_args
        assert_attribute_exists(@node_name, @attr_ary)
      end

      # Runs knife command.
      #
      # @return void
      # @raise [ArgumentError] if the attribute path format or the user list is
      #   wrong.
      # @raise [UnacceptableEncryptedAttributeFormat] if encrypted attribute
      #   format is wrong or does not exist.
      # @raise [UnsupportedEncryptedAttributeFormat] if encrypted attribute
      #   format is not supported or unknown.
      # @raise [EncryptionFailure] if there are encryption errors.
      # @raise [MessageAuthenticationFailure] if HMAC calculation error.
      # @raise [InvalidPublicKey] if it is not a valid RSA public key.
      # @raise [InvalidKey] if the RSA key format is wrong.
      # @raise [InsufficientPrivileges] if you lack enough privileges to read
      #   the keys from the Chef Server.
      # @raise [ClientNotFound] if client does not exist.
      # @raise [Net::HTTPServerException] for Chef Server HTTP errors.
      # @raise [RequirementsFailure] if the specified encrypted attribute
      #   version cannot be used.
      # @raise [SearchFailure] if there is a Chef search error.
      # @raise [SearchFatalError] if the Chef search response is wrong.
      # @raise [InvalidSearchKeys] if search keys structure is wrong.
      def run
        parse_args

        # update encrypted attribute
        knife_config = Chef::Config[:knife][:encrypted_attributes]
        enc_attr = Chef::EncryptedAttribute.new(knife_config)
        if enc_attr.update_on_node(@node_name, @attr_ary)
          ui.info('Encrypted attribute updated.')
        else
          ui.info('Encrypted attribute does not need updating.')
        end
      end
    end
  end
end
