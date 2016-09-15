# encoding: UTF-8
#
# Author:: Lisa Danz (<lisa.danz@opower.com>)
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2015 Onddo Labs, SL.
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

class Chef
  class EncryptedAttribute
    # Helper module to abstract the required Yajl (JSON) dependecy.
    module Yajl
      # Loads the required Yajl JSON library depending on the installed Chef
      # version.
      #
      # * Loads the `yajl` gem in Chef `< 11.13`.
      # * Loads the `ffi_yajl` gem in Chef `>= 11.13`.
      #
      # @return [Class] The correct JSON class to use.
      def self.load_requirement(chef_version)
        if Gem::Requirement.new('< 11.13').satisfied_by?(
          Gem::Version.new(chef_version)
        )
          require 'yajl'
          ::Yajl
        else
          require 'ffi_yajl'
          ::FFI_Yajl
        end
      end
    end
  end
end
