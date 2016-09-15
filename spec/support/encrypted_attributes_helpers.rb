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

require 'chef/api_client'

# Helpers to work with Encrypted Attributes
module EncryptedAttributesHelpers
  def class_from_string(str)
    str.split('::').reduce(Kernel) do |scope, const_name|
      scope.const_get(const_name, scope == Kernel)
    end
  end

  def cache_size(type, size)
    class_from_string("Chef::EncryptedAttribute::Remote#{type.capitalize}")
      .cache.max_size(size)
  end

  def clear_cache(type)
    class_from_string("Chef::EncryptedAttribute::Remote#{type.capitalize}")
      .cache.clear
  end

  def clear_all_caches
    %w(clients node nodes users).each do |type|
      clear_cache(type)
    end
  end

  def create_ssl_key(arg = 2048)
    OpenSSL::PKey::RSA.new(arg)
  end
end
