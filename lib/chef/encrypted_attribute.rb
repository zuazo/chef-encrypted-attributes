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
      @@config ||= Config.new
      @@config.update!(arg) unless arg.nil?
      @@config
    end

    def self.load(hs, c={})
      Chef::Log.debug("#{self.class.name}: Loading Local Encrypted Attribute from: #{hs.to_s}")
      body = AttributeBody.new(config.merge(c))
      result = body.load(hs)
      Chef::Log.debug("#{self.class.name}: Local Encrypted Attribute loaded.")
      result
    end

    def self.load_from_node(name, attr_ary, c={})
      Chef::Log.debug("#{self.class.name}: Loading Remote Encrypted Attribute from #{name}: #{attr_ary.to_s}")
      body = AttributeBody.new(config.merge(c))
      result = body.load_from_node(name, attr_ary)
      Chef::Log.debug("#{self.class.name}: Remote Encrypted Attribute loaded.")
      result
    end

    def self.create(hs, c={})
      Chef::Log.debug("#{self.class.name}: Creating Encrypted Attribute.")
      body = AttributeBody.new(config.merge(c))
      result = body.create(hs)
      Chef::Log.debug("#{self.class.name}: Encrypted Attribute created.")
      result
    end

    def self.update(hs, c={})
      Chef::Log.debug("#{self.class.name}: Updating Encrypted Attribute: #{hs.to_s}")
      body = AttributeBody.new(config.merge(c))
      result = body.update(hs)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute updated.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not updated.")
      end
      result
    end

    def self.exists?(hs)
      Chef::Log.debug("#{self.class.name}: Checking if Encrypted Attribute exists here: #{hs.to_s}")
      result = AttributeBody.exists?(hs)
      if result
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute found.")
      else
        Chef::Log.debug("#{self.class.name}: Encrypted Attribute not found.")
      end
      result
    end

  end
end
