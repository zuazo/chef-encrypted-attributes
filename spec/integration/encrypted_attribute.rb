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

require 'integration_helper'
require 'chef/api_client'

describe Chef::EncryptedAttribute do
  extend ChefZero::RSpec
  let(:encrypted_mash_class) { Chef::EncryptedAttribute::EncryptedMash }
  let(:json_class) { encrypted_mash_class::JSON_CLASS }
  let(:chef_type) { encrypted_mash_class::CHEF_TYPE }
  let(:chef_type_value) { encrypted_mash_class::CHEF_TYPE_VALUE }
  before(:all) do
    clear_all_caches
    cache_size(:node, 0)
  end
  after { Chef::Config[:encrypted_attributes] = Mash.new }

  when_the_chef_server 'is ready to rock!' do

    versions = %w(default 0 1)
    versions << '2' if ruby_gte_20? && openssl_gte_101?

    versions.each do |version|
      context "EncryptedAttribute version #{version}" do
        before do
          if version != 'default'
            Chef::Config[:encrypted_attributes][:version] = version
          end
        end

        context '#create' do
          before do
            @enc_attr =
              Chef::EncryptedAttribute.create('A coconut yogourts lover')
          end

          it 'creates an encrypted attribute' do
            expect(@enc_attr[chef_type]).to eql(chef_type_value)
          end

          it 'sets the encrypted attribute version' do
            expect(@enc_attr[json_class]).to be_kind_of(String)
          end

          it 'sets the encrypted attribute version correctly',
             if: version == 'default' do
            expect(@enc_attr[json_class])
              .to match(/^Chef::EncryptedAttribute::EncryptedMash::Version/)
          end

          it 'sets the encrypted attribute version correctly',
             if: version != 'default' do
            expect(@enc_attr[json_class])
              .to eql(
                "Chef::EncryptedAttribute::EncryptedMash::Version#{version}"
              )
          end

          it 'creates the correct version object' do
            expect(@enc_attr).to be_kind_of(encrypted_mash_class)
          end

          it 'creates the correct version object', if: version != 'default' do
            expect(@enc_attr.class.name)
              .to eql(
                "Chef::EncryptedAttribute::EncryptedMash::Version#{version}"
              )
          end

        end # context #create

        context 'loading the encrypted attribute' do
          before do
            @clear_attr = Mash.new(
              complex: 'object',
              more_complexity: [1, 'hated string'],
              raving: { 'more random stuff' => [3.0, true, false, nil] }
            )
            @enc_attr = Chef::EncryptedAttribute.create(@clear_attr)
          end

          context 'using #load' do
            it 'is able to decrypt the attribute' do
              expect { Chef::EncryptedAttribute.load(@enc_attr) }
                .not_to raise_error
            end

            it 'decrypts the attribute to the correct value' do
              expect(Chef::EncryptedAttribute.load(@enc_attr))
                .to eql(@clear_attr)
            end
          end # context using #load

          context 'using #load_from_node' do
            before do
              @node = Chef::Node.new
              @node.name(Chef::Config[:node_name])
              @node.set['encrypted']['attribute'] = @enc_attr
              @node.save
            end
            after { @node.destroy }

            it 'is able to decrypt the attribute' do
              expect do
                Chef::EncryptedAttribute.load_from_node(
                  Chef::Config[:node_name], %w(encrypted attribute)
                )
              end.not_to raise_error
            end

            it 'decrypts the attribute to the correct value' do
              expect(
                Chef::EncryptedAttribute.load_from_node(
                  Chef::Config[:node_name], %w(encrypted attribute)
                )
              ).to eql(@clear_attr)
            end

            it 'throws an error if not found' do
              expect do
                Chef::EncryptedAttribute.load_from_node(
                  Chef::Config[:node_name], %w(bad encrypted attribute)
                )
              end.to raise_error(
                Chef::EncryptedAttribute::UnacceptableEncryptedAttributeFormat,
                'Encrypted attribute not found or corrupted.'
              )
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
            [0, 1.0, '2'],
            { 'bob' => 'alice' }
          ]

          objects_to_test.each do |o|

            it "#load encrypts and decrypts correctly: #{o.inspect} "\
               "(#{o.class})" do
              enc_o = Chef::EncryptedAttribute.create(o)
              expect(Chef::EncryptedAttribute.load(enc_o)).to eql(o)
            end

            it "#load_from_node encrypts and decrypts correctly: #{o.inspect} "\
               "(#{o.class})" do
              enc_o = Chef::EncryptedAttribute.create(o)
              node = Chef::Node.new
              node.name(Chef::Config[:node_name])
              node.set['enc_o'] = enc_o
              node.save
              expect(
                Chef::EncryptedAttribute.load_from_node(
                  Chef::Config[:node_name], %w(enc_o)
                )
              ).to eql(o)
              node.destroy
            end

          end # objects_to_test.each
        end # context #create & #load testing some basic types

        context '#update' do
          before do
            Chef::Config[:encrypted_attributes][:client_search] = %w(admin:true)
            Chef::Config[:encrypted_attributes][:node_search] = %w(role:webapp)
            # disable remote clients cache
            cache_size(:clients, 0)
            cache_size(:nodes, 0)

            @client1 = chef_create_admin_client('client1')

            @node1, @node1_client = chef_create_node('node1') do |node|
              node.run_list << 'role[webapp]'
            end

            @enc_attr = Chef::EncryptedAttribute.create('Testing updates')
          end
          after do
            @client1.destroy
            @node1_client.destroy
            @node1.destroy
          end

          it 'does not update an already updated attribute' do
            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(false)
            expect(@enc_attr).to eql(enc_orig)
          end

          it 'updates when there are new clients' do
            # creating a new admin client will require an update
            client2 = chef_create_admin_client('client2')

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            client2.destroy
          end

          it 'updates when some clients are removed' do
            @client1.destroy

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            @client1.save # avoid error 404 on after { client1.destroy }
          end

          it 'updates when some clients are added and others removed' do
            @client1.destroy
            client2 = chef_create_admin_client('client2')

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            client2.destroy
            @client1.save # avoid error 404 on after { client1.destroy }
          end

          it 'updates when there are new nodes' do
            # creating a new admin node will require an update
            node2 = Chef::Node.new
            node2.name('node2')
            node2.run_list << 'role[webapp]'
            node2.save
            node2_client = Chef::ApiClient.new
            node2_client.name(node2.name)
            node2_client.save

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            node2_client.destroy
            node2.destroy
          end

          it 'updates when some nodes are removed' do
            @node1.destroy

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            @node1.save # avoid error 404 on after { node1.destroy }
          end

          it 'updates when some clients are added and others removed' do
            @node1.destroy
            node2 = Chef::Node.new
            node2.name('node2')
            node2.run_list << 'role[webapp]'
            node2.save
            node2_client = Chef::ApiClient.new
            node2_client.name(node2.name)
            node2_client.save

            enc_orig = @enc_attr.clone
            expect(Chef::EncryptedAttribute.update(@enc_attr)).to eql(true)
            expect(@enc_attr).not_to eql(enc_orig)

            node2_client.destroy
            node2.destroy
            @node1.save # avoid error 404 on after { node1.destroy }
          end

        end # context #update

        context '#exist?' do

          clear_attributes = [
            nil,
            2,
            'Spoon-bender',
            Hash.new,
            Mash.new,
            Mash.new('version' => '1'),
            begin
              node = Chef::Node.new
              node.name(Chef::Config[:node_name])
              node.set['clear']['attribute'] = 'clear_node_attribute'
              node['clear']['attribute']
            end
          ]

          clear_attributes.each do |a|

            it "returns false for #{a.inspect}" do
              expect(Chef::Log).to_not receive(:warn)
              expect(Chef::EncryptedAttribute.exist?(a)).to eql(false)
            end

          end

          it 'returns true for an encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')

            expect(Chef::Log).to_not receive(:warn)
            expect(Chef::EncryptedAttribute.exist?(enc_attr)).to eql(true)
          end

          it 'returns true for a node encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')
            node = Chef::Node.new
            node.name(Chef::Config[:node_name])
            node.set['encrypted']['attribute'] = enc_attr

            expect(Chef::Log).to_not receive(:warn)
            expect(
              Chef::EncryptedAttribute.exist?(node['encrypted']['attribute'])
            ).to eql(true)
          end

        end # context #exist?

        context '#exists?' do

          clear_attributes = [
            nil,
            2,
            'Spoon-bender',
            Hash.new,
            Mash.new,
            Mash.new('version' => '1'),
            begin
              node = Chef::Node.new
              node.name(Chef::Config[:node_name])
              node.set['clear']['attribute'] = 'clear_node_attribute'
              node['clear']['attribute']
            end
          ]

          clear_attributes.each do |a|

            it "returns false for #{a.inspect}" do
              expect(Chef::Log).to receive(:warn).once
                .with(/is deprecated in favor of/)
              expect(Chef::EncryptedAttribute.exists?(a)).to eql(false)
            end

          end

          it 'returns true for an encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')

            expect(Chef::Log).to receive(:warn).once
              .with(/is deprecated in favor of/)
            expect(Chef::EncryptedAttribute.exists?(enc_attr)).to eql(true)
          end

          it 'returns true for a node encrypted attribute' do
            enc_attr = Chef::EncryptedAttribute.create('any-data')
            node = Chef::Node.new
            node.name(Chef::Config[:node_name])
            node.set['encrypted']['attribute'] = enc_attr

            expect(Chef::Log).to receive(:warn).once
              .with(/is deprecated in favor of/)
            expect(Chef::EncryptedAttribute.exists?(
              node['encrypted']['attribute']
            )).to eql(true)
          end

        end # context #exists?

        context 'working with multiple clients' do
          before do
            @attr_clear = 'A coconut yogourts lover'

            @node = Chef::Node.new
            @node.name('node1')
            @node.set['encrypted']['attribute'] =
              Chef::EncryptedAttribute.create(@attr_clear)
            @node.save

            @node_client = Chef::ApiClient.new
            @node_client.name(@node.name)
            client_hs = @node_client.save
            @node_client.public_key(client_hs['public_key'])
            @node_client.private_key(client_hs['private_key'])
            @private_key = create_ssl_key(@node_client.private_key)
          end
          after do
            @node.destroy
            @node_client.destroy
          end

          it 'original client is able to read the attribute' do
            expect(Chef::EncryptedAttribute.load(
              @node['encrypted']['attribute']
            )).to eql(@attr_clear)
          end

          it 'other clients does not be able to read it by default' do
            allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
              .to receive(:key).and_return(@private_key)
            expect do
              expect(Chef::EncryptedAttribute.load(
                @node['encrypted']['attribute']
              )).to eql(@attr_clear)
            end.to raise_error(
              Chef::EncryptedAttribute::DecryptionFailure,
              /Attribute data cannot be decrypted by the provided key\./
            )
          end

          it 'other clients is able to read it if added as #udpate arg' do
            Chef::EncryptedAttribute.update(
              @node.set['encrypted']['attribute'],
              keys: [@node_client.public_key]
            )

            allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
              .to receive(:key).and_return(@private_key)
            expect(Chef::EncryptedAttribute.load(
              @node['encrypted']['attribute']
            )).to eql(@attr_clear)
          end

          it 'other clients is able to read it if added in global config' do
            Chef::Config[:encrypted_attributes][:keys] =
              [@node_client.public_key]
            expect(Chef::EncryptedAttribute.update(
              @node.set['encrypted']['attribute']
            )).to eql(true)

            allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
              .to receive(:key).and_return(@private_key)
            expect(Chef::EncryptedAttribute.load(
              @node['encrypted']['attribute']
            )).to eql(@attr_clear)
          end

          it 'other clients does not be able to read if they are removed from '\
             'global config' do
            # first add the key
            Chef::Config[:encrypted_attributes][:keys] =
              [@node_client.public_key]
            # update with the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'])
            Chef::Config[:encrypted_attributes][:keys] = [] # remove the key
            # update without the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'])

            allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
              .to receive(:key).and_return(@private_key)
            expect do
              Chef::EncryptedAttribute.load(@node['encrypted']['attribute'])
            end.to raise_error(
              Chef::EncryptedAttribute::DecryptionFailure,
              /Attribute data cannot be decrypted by the provided key\./
            )
          end

          it 'other clients does not be able to read if they are not removed '\
             'from global config' do
            # first add the key
            Chef::Config[:encrypted_attributes][:keys] =
              [@node_client.public_key]
            # update with the key
            Chef::EncryptedAttribute.update(@node.set['encrypted']['attribute'])
            # update without the key
            Chef::EncryptedAttribute.update(
              @node.set['encrypted']['attribute'], keys: []
            )

            allow_any_instance_of(Chef::EncryptedAttribute::LocalNode)
              .to receive(:key).and_return(@private_key)
            expect do
              expect(Chef::EncryptedAttribute.load(
                @node['encrypted']['attribute']
              )).to eql(@attr_clear)
            end.to raise_error(
              Chef::EncryptedAttribute::DecryptionFailure,
              /Attribute data cannot be decrypted by the provided key\./
            )
          end

        end # context working with multiple clients
      end # context EncryptedAttribute version #{version}
    end # each do |version|
  end # when_the_chef_server is ready to rock!
end
