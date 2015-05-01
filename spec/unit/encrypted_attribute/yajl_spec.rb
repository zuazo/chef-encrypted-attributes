require 'spec_helper'
require 'chef/encrypted_attribute/yajl'

describe Chef::EncryptedAttribute::Yajl do
  context '.load_requirement' do
    [
      { chef_version: '11.8.0',  library: 'yajl',     namespace: 'Yajl' },
      { chef_version: '11.12.8', library: 'yajl',     namespace: 'Yajl' },
      { chef_version: '11.14.0', library: 'ffi_yajl', namespace: 'FFI_Yajl' },
      { chef_version: '12.3.0',  library: 'ffi_yajl', namespace: 'FFI_Yajl' }
    ].each do |test|
      it "given #{test[:chef_version].inspect}, requires "\
          "#{test[:library].inspect} and returns #{test[:namespace]}" do
        expect(described_class).to receive(:require).with(test[:library])
        namespace = double('Constant')
        stub_const(test[:namespace], namespace)
        expect(described_class.load_requirement(test[:chef_version]))
          .to eq namespace
      end
    end
  end
end
