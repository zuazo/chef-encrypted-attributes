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

require 'chef/knife'

class Chef
  class Knife
    module Core
      # Loads knife encrypted attribute dependencies.
      module EncryptedAttributeDepends
        # Reopens EncryptedAttributeDepends class to define knife dependencies.
        #
        # Includes the required gems to work with encrypted attributes.
        #
        # @param includer [Class] includer class.
        def self.included(includer)
          includer.class_eval do
            deps do
              require 'chef/encrypted_attribute'
              require 'chef/json_compat'
            end
          end
        end
      end
    end
  end
end
