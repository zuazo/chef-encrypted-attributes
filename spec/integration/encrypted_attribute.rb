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
require 'chef/api_client'

describe Chef::EncryptedAttribute do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do

    %w{default 0 1}.each do |version|
      context "EncryptedAttribute version #{version}" do
        before do
          Chef::EncryptedAttribute.config.reset
          Chef::EncryptedAttribute.config.version(version) if version != 'default'
        end

        context '#create' do
          before do
            @Base = Chef::EncryptedAttribute::EncryptedMash::Base
            @json_class = @Base::JSON_CLASS
            @chef_type = @Base::CHEF_TYPE
            @chef_type_value = @Base::CHEF_TYPE_VALUE
            @enc_attr = Chef::EncryptedAttribute.create('A coconut yogourts lover')
          end

          it 'should create an encrypted attribute' do
            @enc_attr[@chef_type].should eql(@chef_type_value)
          end

          it 'should set the encrypted attribute version' do
            @enc_attr[@json_class].should be_kind_of(String)
          end

          it 'should set the encrypted attribute version correctly', :if => version == 'default' do
            @enc_attr[@json_class].should match(/^Chef::EncryptedAttribute::EncryptedMash::Version/)
          end

          it 'should set the encrypted attribute version correctly', :if => version != 'default' do
            @enc_attr[@json_class].should eql("Chef::EncryptedAttribute::EncryptedMash::Version#{version}")
          end

          it 'should create the correct version object' do
            @enc_attr.should be_kind_of(@Base)
          end

          it 'should create the correct version object', :if => version != 'default' do
            @enc_attr.class.name.should eql("Chef::EncryptedAttribute::EncryptedMash::Version#{version}")
          end

        end # context #create

        context 'loading the encrypted attribute' do
          before do
            @clear_attr = Mash.new({
              :complex => 'object',
              :more_complexity => [ 1, 'hated string' ],
              :raving => { 'more random stuff' => [ 3.0, true, false, nil ] },
            })
            @enc_attr = Chef::EncryptedAttribute.create(@clear_attr)
          end

          context 'using #load' do
            it 'should be able to decrypt the attribute' do
              lambda { Chef::EncryptedAttribute.load(@enc_attr) }.should_not raise_error
            end

            it 'should decrypt the attribute to the correct value' do
              Chef::EncryptedAttribute.load(@enc_attr).should eql(@clear_attr)
            end
          end # context using #load

          context 'using #load_from_node' do
            before do
              @node = Chef::Node.new
              @node.name(Chef::Config[:node_name])
              @node.set['encrypted']['attribute'] = @enc_attr
              @node.save
            end
            after do
              @node.destroy
            end

            it 'should be able to decrypt the attribute' do
              lambda { Chef::EncryptedAttribute.load_from_node(Chef::Config[:node_name], [ 'encrypted', 'attribute' ]) }.should_not raise_error
            end

            it 'should decrypt the attribute to the correct value' do
              Chef::EncryptedAttribute.load_from_node(Chef::Config[:node_name], [ 'encrypted', 'attribute' ]).should eql(@clear_attr)
            end
          end # context using #load_from_node

        end # context loading the encrypted attribute

        context '#create & #load testing some basic types' do
          objects_to_test = [
            0.0,
            2,
            3.0,
            '',
            '"',
            "'",
            '"\'"\'',
            true,
            false,
            nil,
            [ 0, 1.0, '2' ],
            { 'bob' => 'alice' },
          ]

          objects_to_test.each do |o|

            it "#load should encrypt and decrypt correctly: #{o.inspect} (#{o.class})" do
              enc_o = Chef::EncryptedAttribute.create(o)
              Chef::EncryptedAttribute.load(enc_o).should eql(o)
            end

            it "#load_from_node should encrypt and decrypt correctly: #{o.inspect} (#{o.class})" do
              enc_o = Chef::EncryptedAttribute.create(o)
              node = Chef::Node.new
              node.name(Chef::Config[:node_name])
              node.set['enc_o'] = enc_o
              node.save
              Chef::EncryptedAttribute.load_from_node(Chef::Config[:node_name], [ 'enc_o' ] ).should eql(o)
              node.destroy
            end

          end # objects_to_test.each
        end # context #create & #load testing some basic types

        context '#update' do
          before do
            Chef::EncryptedAttribute.config.client_search([ 'admin:true' ])

            @client1 = Chef::ApiClient.new
            @client1.name('client1')
            @client1.admin(true)
            @client1.save

            @enc_attr = Chef::EncryptedAttribute.create('Testing updates')
          end
          after do
            @client1.destroy
          end

          it 'should not update an already updated attribute' do
            enc_orig = @enc_attr.clone
            Chef::EncryptedAttribute.update(@enc_attr).should eql(false)
            @enc_attr.should eql(enc_orig)
          end

          it 'should update when there are new clients' do
            # creating a new admin client will require a update
            client2 = Chef::ApiClient.new
            client2.name('client2')
            client2.admin(true)
            client2.save

            enc_orig = @enc_attr.clone
            Chef::EncryptedAttribute.update(@enc_attr).should eql(true)
            @enc_attr.should_not eql(enc_orig)

            client2.destroy
          end

          it 'should update when some clients are removed' do
            @client1.destroy

            enc_orig = @enc_attr.clone
            Chef::EncryptedAttribute.update(@enc_attr).should eql(true)
            @enc_attr.should_not eql(enc_orig)

            @client1.save # avoid error 404 on after { client1.destroy }
          end

          it 'should update when some clients are added and others removed' do
            @client1.destroy
            client2 = Chef::ApiClient.new
            client2.name('client2')
            client2.admin(true)
            client2.save

            enc_orig = @enc_attr.clone
            Chef::EncryptedAttribute.update(@enc_attr).should eql(true)
            @enc_attr.should_not eql(enc_orig)

            client2.destroy
            @client1.save # avoid error 404 on after { client1.destroy }
          end

        end # context #update

        context '#exists?' do

          clear_attributes = [
            nil,
            2,
            'Spoon-bender',
            Hash.new,
            Mash.new,
            Mash.new({
              'version' => '1',
            }),
            begin
              node = Chef::Node.new
              node.name(Chef::Config[:node_name])
              node.set['clear']['attribute'] = 'clear_node_attribute'
              node['clear']['attribute']
            end,
          ]

          clear_attributes.each do |a|

            it "should return false for #{a.inspect}" do
              Chef::EncryptedAttribute.exists?(a).should eql(false)
            end

          end

          it 'should return true for an encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')

            Chef::EncryptedAttribute.exists?(enc_attr).should eql(true)
          end

          it 'should return true for a node encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')
            node = Chef::Node.new
            node.name(Chef::Config[:node_name])
            node.set['encrypted']['attribute'] = enc_attr

            Chef::EncryptedAttribute.exists?(node['encrypted']['attribute']).should eql(true)
          end

        end # context #exists?

        context 'working with multiple clients' do
          before do
            @attr_clear = 'A coconut yogourts lover'
            Chef::EncryptedAttribute.config.reset

            @node = Chef::Node.new
            @node.name('client1')
            @node.set['encrypted']['attribute'] = Chef::EncryptedAttribute.create(@attr_clear)
            @node.save

            @client = Chef::ApiClient.new
            @client.name('client1')
            client_hs = @client.save
            @client.public_key(client_hs['public_key'])
            @client.private_key(client_hs['private_key'])
            @client
          end
          after do
            @node.destroy
            @client.destroy
          end

          it 'original client should be able to read the attribute' do
            Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear)
          end

          it 'other clients should not be able to read it by default' do
            Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client.private_key)
            lambda { Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
          end

          it 'other clients should be able to read it if added as #udpate arg' do
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'], { :keys => [ @client.public_key ] })

            Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client.private_key)
            Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear)
          end

          it 'other clients should be able to read it if added in global config' do
            Chef::EncryptedAttribute.config.add_key(@client.public_key)
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'])

            Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client.private_key)
            Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear)
          end

          it 'other clients should not be able to read if they are removed from global config' do
            Chef::EncryptedAttribute.config.add_key(@client.public_key) # first add the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute']) # update with the key
            Chef::EncryptedAttribute.config.keys([]) # removed the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute']) # update without the key

            Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client.private_key)
            lambda { Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
          end

          it 'other clients should not be able to read if they are removed using #udpate arg' do
            Chef::EncryptedAttribute.config.add_key(@client.public_key) # first add the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute']) # update with the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'], { :keys => [] }) # update without the key

            Chef::EncryptedAttribute::LocalNode.any_instance.stub(:key).and_return(@client.private_key)
            lambda { Chef::EncryptedAttribute.load(@node['encrypted']['attribute']).should eql(@attr_clear) }.should raise_error(Chef::EncryptedAttribute::DecryptionFailure, /Attribute data cannot be decrypted by the provided key\./)
          end

        end # context working with multiple clients

      end # context EncryptedAttribute version #{version}
    end # each do |version|
  end # when_the_chef_server is ready to rock!
end
