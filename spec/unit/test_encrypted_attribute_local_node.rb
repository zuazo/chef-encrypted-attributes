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

require 'spec_helper'
require 'chef/exceptions'

describe Chef::EncryptedAttribute::LocalNode do
  before do
    @LocalNode = Chef::EncryptedAttribute::LocalNode
    @local_node = @LocalNode.new
    Chef::Config[:node_name] = 'server1'
    Chef::Config[:client_key] = "#{File.dirname(__FILE__)}/../data/client.pem"
  end

  it 'should create a remote node without errors' do
    lambda { @LocalNode.new }.should_not raise_error
  end

  it '#name should return the local server name' do
    @local_node.name.should eql(Chef::Config[:node_name])
  end

  it '#key should return a PKey::RSA instance' do
    @local_node.key.should be_an_instance_of(OpenSSL::PKey::RSA)
  end

  it '#key should return the local server key' do
    key = OpenSSL::PKey::RSA.new(open(Chef::Config[:client_key]).read())
    @local_node.key.to_s.should eql(key.to_s)
  end

  it '#public_key should return a RSA instance' do
    @local_node.public_key.should be_an_instance_of(OpenSSL::PKey::RSA)
  end

  it '#public_key should return the local server public_key' do
    public_key = OpenSSL::PKey::RSA.new(open(Chef::Config[:client_key]).read()).public_key
    @local_node.public_key.to_s.should eql(public_key.to_s)
  end

end
