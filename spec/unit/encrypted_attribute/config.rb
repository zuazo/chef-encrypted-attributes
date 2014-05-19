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
    expect { @Config.new }.not_to raise_error
  end

  it 'should update the configuration from the constructor' do
    expect(Chef::Log).not_to receive(:warn)
    config_hs = { :partial_search => true }
    expect_any_instance_of(@Config).to receive(:update!).with(config_hs).once
    config = @Config.new(config_hs)
  end

  it 'should warn about unknown configuration values' do
    expect(Chef::Log).to receive(:warn).once
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
          [ OpenSSL::PKey::RSA.new(128) ],
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem, OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem, OpenSSL::PKey::RSA.new(128) ],
        ],
        :error => [
          true, false, 1, 0.2, 'any-string', Hash.new,
          OpenSSL::PKey::RSA.new(128),
          [ OpenSSL::PKey::RSA.new(128).public_key.to_pem, 4 ],
          [ 'bad-key' ],
          # TODO non-public key string arrays
        ],
      },
    }.each do |method, values|

      describe "##{method}" do

        it "should return the correct default value (#{values[:default].inspect[0..10]}...)" do
          expect(@config.send(method)).to eql(values[:default])
        end

        values[:ok].each do |v_ok|
          it "should accept #{v_ok.class.to_s} type (#{v_ok.inspect.inspect[0..10]}...)" do
            expect { @config.send(method, v_ok) }.not_to raise_error
            expect(@config.send(method)).to eql(v_ok)
          end
        end

        values[:error].each do |v_error|
          it "should not accept #{v_error.class.to_s} type (#{v_error.inspect[0..10]}...)" do
            expect { @config.send(method, v_error) }.to raise_error(Chef::Exceptions::ValidationFailed)
          end
        end

      end # describe method


    end # methods each

    it '#client_search should accept String type tunrning it into an Array' do
      expect { @config.client_search('admin:false') }.not_to raise_error
      expect(@config.client_search).to eql([ 'admin:false' ])
    end

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
        expect(@config.version).to eql(config2.version)
      end

      it 'should update partial_search values from a @Config class' do
        config2 = @Config.new
        config2.partial_search(false)
        @config.update!(config2)
        expect(@config.partial_search).to eql(config2.partial_search)
      end

      it 'should update client_search values from a @Config class' do
        config2 = @Config.new
        config2.client_search([ '*:*' ])
        @config.update!(config2)
        expect(@config.client_search).to eql(config2.client_search)
      end

      it 'should update users values from a @Config class' do
        config2 = @Config.new
        config2.users([ 'admin' ])
        @config.update!(config2)
        expect(@config.users).to eql(config2.users)
      end

      it 'should update keys values from a @Config class' do
        config2 = @Config.new
        config2.keys([ OpenSSL::PKey::RSA.new(128).public_key.to_pem ])
        @config.update!(config2)
        expect(@config.keys).to eql(config2.keys)
      end

      it 'should update version value from a Hash with symbol keys' do
        config2 = { :version => 5 }
        @config.update!(config2)
        expect(@config.version).to eql(config2[:version])
      end

      it 'should update partial_search value from a Hash with symbol keys' do
        config2 = { :partial_search => false }
        @config.update!(config2)
        expect(@config.partial_search).to eql(config2[:partial_search])
      end

      it 'should update client_search value from a Hash with symbol keys' do
        config2 = { :client_search => [ '*:*' ] }
        @config.update!(config2)
        expect(@config.client_search).to eql(config2[:client_search])
      end

      it 'should update users value from a Hash with symbol keys' do
        config2 = { :users => [ 'admin' ] }
        @config.update!(config2)
        expect(@config.users).to eql(config2[:users])
      end

      it 'should update keys value from a Hash with symbol keys' do
        config2 = { :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ] }
        @config.update!(config2)
        expect(@config.keys).to eql(config2[:keys])
      end

      it 'should update multiple values from a Hash with different kind of keys' do
        config2 = {
          'partial_search' => false,
          :client_search => [],
          :keys => [ OpenSSL::PKey::RSA.new(128).public_key.to_pem ],
        }
        @config.update!(config2)

        expect(@config.partial_search).to eql(config2['partial_search'])
        expect(@config.client_search).to eql(config2[:client_search])
        expect(@config.keys).to eql(config2[:keys])
      end

    end # describe #update!

    context '#[]' do

        it 'should read a configuration variable' do
          config = @Config.new({ :partial_search => true })
          expect(config[:partial_search]).to eql(true)
        end

        it 'should ignore non existing configuration options' do
          config = @Config.new
          expect { config[:random_config_options] }.not_to raise_error
        end

    end

    context '#[]=' do

        it 'should write a configuration variable' do
          config = @Config.new({ :partial_search => false })
          expect(config[:partial_search]).to eql(false)
          config[:partial_search] = true
          expect(config[:partial_search]).to eql(true)
        end

        it 'should ignore non existing configuration options' do
          config = @Config.new
          expect { config[:random_config_options] = 5 }.not_to raise_error
        end

    end

  end # describe Chef::EncryptedAttribute::Config instance

end # describe Chef::EncryptedAttribute::Config
