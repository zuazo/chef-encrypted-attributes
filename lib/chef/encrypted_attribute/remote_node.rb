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

require 'chef/mixin/params_validate'
require 'chef/encrypted_attribute/search_helper'

class Chef
  class EncryptedAttribute
    class RemoteNode
      include ::Chef::Mixin::ParamsValidate
      include ::Chef::EncryptedAttribute::SearchHelper

      def initialize(name)
        name(name)
      end

      def name(arg=nil)
        set_or_return(
          :name,
          arg,
          :kind_of => String
        )
      end

      def load_attribute(attr_ary, partial_search=true)
        unless attr_ary.kind_of?(Array)
          raise ArgumentError, "#{self.class.to_s}##{__method__} attr_ary argument must be an array of strings. You passed #{attr_ary.inspect}."
        end
        keys = { 'value' => attr_ary }
        res = search(:node, "name:#{@name}", keys, 1, partial_search)
        if res.kind_of?(Array) and res[0].kind_of?(Hash) and
           res[0].has_key?('value')
          res[0]['value']
        else
          nil
        end
      end

    end
  end
end
