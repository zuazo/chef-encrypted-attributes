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

require 'integration_helper'
require 'chef/knife/encrypted_attribute_show'

describe Chef::Knife::EncryptedAttributeShow do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do
    before do
      Chef::EncryptedAttribute::RemoteClients.cache.clear
      Chef::EncryptedAttribute::RemoteUsers.cache.clear
      Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)

      Chef::Knife::EncryptedAttributeShow.load_deps
      @knife = Chef::Knife::EncryptedAttributeShow.new

      @node = Chef::Node.new
      @node.name('node1')
      @node.set['encrypted']['attribute'] = Chef::EncryptedAttribute.create('unicorns drill accurately')
      @node.set['encrypted']['attri.bu\\te'] = Chef::EncryptedAttribute.create('escaped unicorns')
      @node.save

      @stdout = StringIO.new
      @knife.ui.stub(:stdout).and_return(@stdout)
    end
    after do
      @node.destroy
    end

    it 'should show the encrypted attribute' do
      @knife.name_args = %w{node1 encrypted.attribute}
      @knife.run
      @stdout.string.should match(/unicorns drill accurately/)
    end

    it 'should show the encrypted attribute if needs to be escaped' do
      @knife.name_args = %w{node1 encrypted.attri\.bu\te}
      @knife.run
      @stdout.string.should match(/escaped unicorns/)
    end

    it 'should print error message when the attribute does not exists' do
      @knife.name_args = %w{node1 non.existent}
      @knife.ui.should_receive(:fatal).with('Encrypted attribute not found')
      lambda { @knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when a node name is not provided' do
      @knife.name_args = []
      @knife.should_receive(:show_usage)
      @knife.ui.should_receive(:fatal)
      lambda { @knife.run }.should raise_error(SystemExit)
    end

    it 'should print usage and exit when an attribute is not provided' do
      @knife.name_args = [ 'node1' ]
      @knife.should_receive(:show_usage)
      @knife.ui.should_receive(:fatal)
      lambda { @knife.run }.should raise_error(SystemExit)
    end

  end
end
