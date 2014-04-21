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
require 'chef/knife/encrypted_attribute_show'

describe Chef::Knife::EncryptedAttributeShow do

  before do
    Chef::Knife::EncryptedAttributeShow.load_deps
    @knife = Chef::Knife::EncryptedAttributeShow.new

    @stdout = StringIO.new
    @knife.ui.stub(:stdout).and_return(@stdout)
  end

  it 'should load the encrypted attribute' do
    Chef::EncryptedAttribute.should_receive(:load_from_node).and_return('unicorns drill accurately')
    @knife.name_args = %w{node1 encrypted.attribute}
    @knife.run
    @stdout.string.should match(/unicorns drill accurately/)
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

  context '#attribute_path_to_ary' do

    {
      'encrypted.attribute' => [ 'encrypted', 'attribute' ],
      '.encrypted.attribute.' => [ '', 'encrypted', 'attribute', '' ],
      'encrypted\\.attribute' => [ 'encrypted.attribute' ],
      'encrypted\\.attribute\\' => [ 'encrypted.attribute\\' ],
      'encrypted\\.attr.i\\\\.bute' => [ 'encrypted.attr', 'i\\\\', 'bute' ],
      'encrypted\\.attr.i\\\\.bu\\\\\.te' => [ 'encrypted.attr', 'i\\\\', 'bu\\\\.te' ],
      'encrypted\\.attr.i\\\\\\\\.bu\\\\\\\\\.te' => [ 'encrypted.attr', 'i\\\\\\\\', 'bu\\\\\\\\.te' ],
    }.each do |str, ary|

      it "should convert #{str.inspect} to #{ary.inspect}" do
        @knife.attribute_path_to_ary(str).should eql(ary)
      end

    end # each do |str, ary|

  end # context #attribute_path_to_ary

end
