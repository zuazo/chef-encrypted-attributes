require 'integration_helper'
require 'chef/api_client'

describe Chef::EncryptedAttribute do
  extend ChefZero::RSpec

  when_the_chef_server 'is ready to rock!' do

    context '#create' do
      before do
        @enc_attr = Chef::EncryptedAttribute.create('A coconut yogourts lover')
      end

      it 'should create and encrypted attribute' do
        @enc_attr['_encryted_attribute'].should eql(true)
      end

      it 'should set the encrypted attribute version' do
        @enc_attr['_version'].should be_kind_of(String)
      end

      it 'should be a correct version' do
        @enc_attr['_version'].should_not be_empty
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

  end # when_the_chef_server is ready to rock!
end
