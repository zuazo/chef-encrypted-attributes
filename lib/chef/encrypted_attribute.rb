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

require 'chef/encrypted_attribute/config'
require 'chef/encrypted_attribute/attribute_body'

class Chef
  class EncryptedAttribute

    def self.config(arg=nil)
      unless arg.nil?
        @@config = Config.new(arg)
      else
        @@config ||= Config.new
      end
    end

    def self.load(hs)
      body = AttributeBody.new(config)
      body.load(hs)
    end

    def self.load_from_node(name, attr_ary)
      body = AttributeBody.new(config)
      body.load_from_node(name, attr_ary)
    end

    def self.create(hs)
      body = AttributeBody.new(config)
      body.create(hs)
    end

    def self.update(hs)
      body = AttributeBody.new(config)
      body.update(hs)
    end

    def self.exists?(hs)
      AttributeBody.exists?(hs)
    end

  end
end
