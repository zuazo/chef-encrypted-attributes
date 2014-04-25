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

describe Chef::EncryptedAttribute::Config do
  before do
    @Config = Chef::EncryptedAttribute::Config
  end

  it 'should create an entire configuration with default values' do
    lambda { @Config.new }.should_not raise_error
  end

  it 'should update the configuration from the constructor' do
    Chef::Log.should_not_receive(:warn)
    config_hs = { :partial_search => true }
    @Config.any_instance.should_receive(:update!).with(config_hs).once
    config = @Config.new(config_hs)
  end

  it 'should warn about unknown configuration values' do
    Chef::Log.should_receive(:warn).once
    @Config.new({
      :unknown_option => 'foo'
    })
  end

  describe "#{Chef::EncryptedAttribute::Config} instance" do
    before do
      @config = @Config.new
    end

    {
      :version => {
        :default => 1,
        :ok => [ 1, 'any-string' ],
        :error => [ true, false, 0.2, Hash.new, Array.new, Object.new ],
      },
      :partial_search => {
        :default => true,
        :ok => [ true, false ],
        :error => [ 1, 0.2, 'any-string', Hash.new, Array.new, Object.new ],
      },
      :client_search => {
        :default => [],
        :ok => [ [ 'admin:false' ], [ 'admin:true', 'admin:false' ], [] ], # string case is treated below separately
        :error => [ 1, 0.2, Hash.new, Object.new ],
      },
      :users => {
        :default => [],
        :ok => [ '*', [], [ 'admin1' ], [ 'admin1', 'admin2' ] ],
        :error => [ 1, 0.2, 'any-string', Hash.new, Object.new, [ 2 ], [ 'admin1', Hash.new ], 'invalid.u$er' ],
      },
      :keys => {
        :default => [],
        :ok => [
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem, OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
        ],
        :error => [
          true, false, 1, 0.2, 'any-string', Hash.new,
          OpenSSL::PKey::RSA.new(128),
          [ OpenSSL::PKey::RSA.new(128) ],
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem, 4 ],
          [ 'bad-key' ],
          # TODO non-public key string arrays
        ],
      },
    }.each do |method, values|

      describe "##{method}" do

        it "should return the correct default value (#{values[:default].inspect[0..10]}...)" do
          @config.send(method).should eql(values[:default])
        end

        values[:ok].each do |v_ok|
          it "should accept #{v_ok.class.to_s} type (#{v_ok.inspect.inspect[0..10]}...)" do
            lambda { @config.send(method, v_ok) }.should_not raise_error
            @config.send(method).should eql(v_ok)
          end
        end

        values[:error].each do |v_error|
          it "should not accept #{v_error.class.to_s} type (#{v_error.inspect[0..10]}...)" do
            lambda { @config.send(method, v_error) }.should raise_error(Chef::Exceptions::ValidationFailed)
          end
        end

      end # describe method


    end # methods each

    it '#client_search should accept String type tunrning it into an Array' do
      lambda { @config.client_search('admin:false') }.should_not raise_error
      @config.client_search.should eql([ 'admin:false' ])
    end

    describe '#add_key' do
      before do
        @key1 = OpenSSL::PKey::RSA.new(128).public_key.to_pem
        @key2 = OpenSSL::PKey::RSA.new(128).public_key.to_pem
      end

      it 'should not allow bad keys' do
        lambda { @config.add_key('bad-key') }.should raise_error(Chef::Exceptions::ValidationFailed)
      end

      it 'should not allow non-public keys' do
        key = OpenSSL::PKey::RSA.new(128)
        key.stub(:public?).and_return(false)
        lambda { @config.add_key(key) }.should raise_error(Chef::Exceptions::ValidationFailed)
      end

      it 'should accept String type' do
        lambda { @config.add_key(@key1) }.should_not raise_error
      end

      it 'should add the strings to the keys attribute' do
        @config.add_key(@key1)
        @config.add_key(@key2)
        @config.keys.should eql([ @key1, @key2 ])
      end

    end # describe #add_key

    describe '#update!' do
      before do
        @config.version(2)
        @config.partial_search(true)
        @config.client_search([ 'admin:true' ])
        @config.users('*')
        @config.keys([ OpenSSL::PKey::RSA.new(128).public_key.to_pem ])
      end

      it 'should update version value from a @Config class' do
        config2 = @Config.new
        config2.version(5)
        @config.update!(config2)
        @config.version.should eql(config2.version)
      end

      it 'should update partial_search values from a @Config class' do
        config2 = @Config.new
        config2.partial_search(false)
        @config.update!(config2)
        @config.partial_search.should eql(config2.partial_search)
      end

      it 'should update client_search values from a @Config class' do
        config2 = @Config.new
        config2.client_search([ '*:*' ])
        @config.update!(config2)
        @config.client_search.should eql(config2.client_search)
      end

      it 'should update users values from a @Config class' do
        config2 = @Config.new
        config2.users([ 'admin' ])
        @config.update!(config2)
        @config.users.should eql(config2.users)
      end

      it 'should update keys values from a @Config class' do
        config2 = @Config.new
        config2.keys([ OpenSSL::PKey::RSA.new(128).public_key.to_pem ])
        @config.update!(config2)
        @config.keys.should eql(config2.keys)
      end

      it 'should update version value from a Hash with symbol keys' do
        config2 = { :version => 5 }
        @config.update!(config2)
        @config.version.should eql(config2[:version])
      end

      it 'should update partial_search value from a Hash with symbol keys' do
        config2 = { :partial_search => false }
        @config.update!(config2)
        @config.partial_search.should eql(config2[:partial_search])
      end

      it 'should update client_search value from a Hash with symbol keys' do
        config2 = { :client_search => [ '*:*' ] }
        @config.update!(config2)
        @config.client_search.should eql(config2[:client_search])
      end

      it 'should update users value from a Hash with symbol keys' do
        config2 = { :users => [ 'admin' ] }
        @config.update!(config2)
        @config.users.should eql(config2[:users])
      end

      it 'should update keys value from a Hash with symbol keys' do
        config2 = { :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ] }
        @config.update!(config2)
        @config.keys.should eql(config2[:keys])
      end

      it 'should update multiple values from a Hash with different kind of keys' do
        config2 = {
          'partial_search' => false,
          :client_search => [],
          :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
        }
        @config.update!(config2)

        @config.partial_search.should eql(config2['partial_search'])
        @config.client_search.should eql(config2[:client_search])
        @config.keys.should eql(config2[:keys])
      end

    end # describe #update!

    describe '#merge' do
      before do
        @config_prev_hs = {
          :version => 3,
          :partial_search => false,
          :client_search => [ 'admin:*' ],
          :users => [ 'admin' ],
          :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
        }
        @config_prev = @Config.new(@config_prev_hs)
      end

      it 'should preserve previous values for default configurations' do
        config2 = @config_prev.merge(@Config.new)
        config2.version.should eql(@config_prev_hs[:version])
        config2.partial_search.should eql(@config_prev_hs[:partial_search])
        config2.client_search.should eql(@config_prev_hs[:client_search])
        config2.users.should eql(@config_prev_hs[:users])
        config2.keys.should eql(@config_prev_hs[:keys])
      end

      it 'should merge version values' do
        config_new = @Config.new({ :version => 4 })
        config_res = @config_prev.merge(config_new)
        config_res.version.should eql(config_new.version)
      end

      it 'should merge partial_search values' do
        config_new = @Config.new({ :partial_search => true })
        config_res = @config_prev.merge(config_new)
        config_res.partial_search.should eql(config_new.partial_search)
      end

      it 'should merge client_search values' do
        config_new = @Config.new({ :client_search => [ 'admin:true' ] })
        config_res = @config_prev.merge(config_new)
        config_res.client_search.should eql(config_new.client_search)
      end

      it 'should merge users values' do
        config_new = @Config.new({ :users => [ 'dev1' ] })
        config_res = @config_prev.merge(config_new)
        config_res.users.should eql(config_new.users)
      end

      it 'should merge keys values' do
        config_new = @Config.new({ :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ] })
        config_res = @config_prev.merge(config_new)
        config_res.keys.should eql(config_new.keys)
      end

    end # describe #merge

    context '#reset' do
      before do
        @config = @Config.new({
          :version => 3,
          :partial_search => false,
          :client_search => [ 'admin:*' ],
          :users => [ 'admin' ],
          :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
        })
      end

      it 'should reset config variables to default' do
        @config.version.should eql(3)
        @config.partial_search.should eql(false)
        @config.client_search.should eql([ 'admin:*' ])
        @config.users.should eql([ 'admin' ])
        @config.keys.should_not eql([])
        @config.reset

        default = @Config.new
        @Config::OPTIONS.each do |opt|
          @config.send(opt).should eql(default.send(opt))
        end
      end

      it 'should support multiple resets' do
        (1..3).step.each do
          lambda { @config.reset }.should_not raise_error
        end
      end

    end # context #clear

    context '#[]' do

        it 'should read a configuration variable' do
          config = @Config.new({ :partial_search => true })
          config[:partial_search].should eql(true)
        end

        it 'should ignore non existing configuration options' do
          config = @Config.new
          lambda { config[:random_config_options] }.should_not raise_error
        end

    end

    context '#[]=' do

        it 'should write a configuration variable' do
          config = @Config.new({ :partial_search => false })
          config[:partial_search].should eql(false)
          config[:partial_search] = true
          config[:partial_search].should eql(true)
        end

        it 'should ignore non existing configuration options' do
          config = @Config.new
          lambda { config[:random_config_options] = 5 }.should_not raise_error
        end

    end

  end # describe Chef::EncryptedAttribute::Config instance

end # describe Chef::EncryptedAttribute::Config
