require 'integration_helper'

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
          node = Chef::Node.new
          node.name(Chef::Config[:node_name])
          node.set['encrypted']['attribute'] = @enc_attr
          node.save
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
        end

      end # objects_to_test.each
    end # context #create & #load testing some basic types

  end
end
