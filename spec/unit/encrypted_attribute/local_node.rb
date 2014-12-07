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

describe Chef::EncryptedAttribute::LocalNode do
  let(:local_node_class) { Chef::EncryptedAttribute::LocalNode }
  let(:local_node) { local_node_class.new }
  before do
    @prev_node_name = Chef::Config[:node_name]
    Chef::Config[:node_name] = 'server1'
    @prev_client_key = Chef::Config[:client_key]
    Chef::Config[:client_key] =
      "#{File.dirname(__FILE__)}/../../data/client.pem"
  end
  after(:all) do
    Chef::Config[:node_name] = @prev_node_name
    Chef::Config[:client_key] = @prev_client_key
  end

  it 'creates a local node without errors' do
    expect { local_node_class.new }.not_to raise_error
  end

  it '#name returns the local node name' do
    expect(local_node.name).to eql(Chef::Config[:node_name])
  end

  it '#key returns a PKey::RSA instance' do
    expect(local_node.key).to be_an_instance_of(OpenSSL::PKey::RSA)
  end

  it '#key returns the local node key' do
    key = create_ssl_key(open(Chef::Config[:client_key]).read)
    expect(local_node.key.to_s).to eql(key.to_s)
  end

  it '#public_key returns a RSA instance' do
    expect(local_node.public_key).to be_an_instance_of(OpenSSL::PKey::RSA)
  end

  it '#public_key returns the local node public_key' do
    public_key =
      create_ssl_key(open(Chef::Config[:client_key]).read).public_key
    expect(local_node.public_key.to_s).to eql(public_key.to_s)
  end

end
