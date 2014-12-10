# encoding: UTF-8
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

require 'chef/api_client'

# Helpers to create objects in the Chef Server
module ChefHelpers
  def chef_create_client(name, admin = false)
    client = Chef::ApiClient.new
    client.name(name)
    client.admin(admin)
    client_hs = client.save
    client.public_key(client_hs['public_key'])
    client.private_key(client_hs['private_key'])
    client
  end

  def chef_create_admin_client(name)
    chef_create_client(name, true)
  end

  def chef_create_user(name, admin = false)
    user = Chef::User.new
    user.name(name)
    user.admin(admin)
    user.save
  end

  def chef_create_admin_user(name)
    chef_create_user(name, true)
  end

  def chef_create_node(name)
    node = Chef::Node.new
    node.name(name)
    yield(node) if block_given?
    node.save
    client = chef_create_client(name)
    [node, client]
  end
end
