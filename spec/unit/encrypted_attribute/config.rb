# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014-2015 Onddo Labs, SL.
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
  extend EncryptedAttributesHelpers

  let(:config_class) { Chef::EncryptedAttribute::Config }

  it 'creates an entire configuration with default values' do
    expect { config_class.new }.not_to raise_error
  end

  it 'updates the configuration from the constructor' do
    expect(Chef::Log).not_to receive(:warn)
    config_hs = { partial_search: true }
    expect_any_instance_of(config_class)
      .to receive(:update!).with(config_hs).once
    config_class.new(config_hs)
  end

  it 'warns about unknown configuration values' do
    expect(Chef::Log).to receive(:warn).once
    config_class.new(unknown_option: 'foo')
  end

  describe "#{Chef::EncryptedAttribute::Config} instance" do
    let(:config) { config_class.new }

    {
      version: {
        default: 1,
        ok: [1, 'any-string'],
        error: [true, false, 0.2, {}, [], Object.new]
      },
      partial_search: {
        default: true,
        ok: [true, false],
        error: [1, 0.2, 'any-string', {}, [], Object.new]
      },
      client_search: {
        default: [],
        # string case is treated below separately
        ok: [%w(admin:false), %w(admin:true admin:false), []],
        error: [1, 0.2, {}, Object.new]
      },
      search_max_rows: {
        default: 1000,
        ok: [5, 10_000],
        error: [true, false, 0.2, 'string', {}, [], Object.new]
      },
      node_search: {
        default: [],
        # string case is treated below separately
        ok: [%w(role:webapp), %w(role:webapp role:ftp), []],
        error: [1, 0.2, {}, Object.new]
      },
      users: {
        default: [],
        ok: ['*', [], %w(admin1), %w(admin1 admin2)],
        error:
          [
            1, 0.2, 'any-string', {}, Object.new, [2],
            ['admin1', {}], 'invalid.u$er'
          ]
      },
      keys: {
        default: [],
        ok: [
          [create_ssl_key],
          [create_ssl_key.public_key.to_pem],
          [
            create_ssl_key.public_key.to_pem,
            create_ssl_key.public_key.to_pem
          ],
          [
            create_ssl_key.public_key.to_pem,
            create_ssl_key
          ]
        ],
        error: [
          true, false, 1, 0.2, 'any-string', {},
          create_ssl_key,
          [create_ssl_key.public_key.to_pem, 4],
          %w(bad-key)
          # TODO: non-public key string arrays
        ]
      }
    }.each do |method, values|
      describe "##{method}" do
        it 'returns the correct default value '\
           "(#{values[:default].inspect[0..10]}...)" do
          expect(config.send(method)).to eql(values[:default])
        end

        values[:ok].each do |v_ok|
          it "accepts #{v_ok.class} type "\
             "(#{v_ok.inspect.inspect[0..10]}...)" do
            expect { config.send(method, v_ok) }.not_to raise_error
            expect(config.send(method)).to eql(v_ok)
          end
        end

        values[:error].each do |v_error|
          it "does not accept #{v_error.class} type "\
             "(#{v_error.inspect[0..10]}...)" do
            expect { config.send(method, v_error) }
              .to raise_error(Chef::Exceptions::ValidationFailed)
          end
        end
      end # describe method
    end # methods each

    it '#client_search accepts String type tunrning it into an Array' do
      expect { config.client_search('admin:false') }.not_to raise_error
      expect(config.client_search).to eql(%w(admin:false))
    end

    it '#node_search  accepts String type tunrning it into an Array' do
      expect { config.node_search('role:webapp') }.not_to raise_error
      expect(config.node_search).to eql(%w(role:webapp))
    end

    describe '#update!' do
      before do
        config.version(2)
        config.partial_search(true)
        config.client_search(%w(admin:true))
        config.node_search([])
        config.users('*')
        config.keys([create_ssl_key.public_key.to_pem])
      end

      it 'updates version value from a config_class class' do
        config2 = config_class.new
        config2.version(5)
        config.update!(config2)
        expect(config.version).to eql(config2.version)
      end

      it 'updates partial_search values from a config_class class' do
        config2 = config_class.new
        config2.partial_search(false)
        config.update!(config2)
        expect(config.partial_search).to eql(config2.partial_search)
      end

      it 'updates client_search values from a config_class class' do
        config2 = config_class.new
        config2.client_search(%w(*:*))
        config.update!(config2)
        expect(config.client_search).to eql(config2.client_search)
      end

      it 'updates node_search values from a config_class class' do
        config2 = config_class.new
        config2.node_search(%w(*:*))
        config.update!(config2)
        expect(config.node_search).to eql(config2.node_search)
      end

      it 'updates users values from a config_class class' do
        config2 = config_class.new
        config2.users(%w(admin))
        config.update!(config2)
        expect(config.users).to eql(config2.users)
      end

      it 'updates keys values from a config_class class' do
        config2 = config_class.new
        config2.keys([create_ssl_key.public_key.to_pem])
        config.update!(config2)
        expect(config.keys).to eql(config2.keys)
      end

      it 'updates version value from a Hash with symbol keys' do
        config2 = { version: 5 }
        config.update!(config2)
        expect(config.version).to eql(config2[:version])
      end

      it 'updates partial_search value from a Hash with symbol keys' do
        config2 = { partial_search: false }
        config.update!(config2)
        expect(config.partial_search).to eql(config2[:partial_search])
      end

      it 'updates client_search value from a Hash with symbol keys' do
        config2 = { client_search: %w(*:*) }
        config.update!(config2)
        expect(config.client_search).to eql(config2[:client_search])
      end

      it 'updates node_search value from a Hash with symbol keys' do
        config2 = { node_search: %w(*:*) }
        config.update!(config2)
        expect(config.node_search).to eql(config2[:node_search])
      end

      it 'updates search_max_rows value from a Hash with symbol keys' do
        config2 = { search_max_rows: 10_000 }
        config.update!(config2)
        expect(config.search_max_rows).to eql(config2[:search_max_rows])
      end

      it 'updates users value from a Hash with symbol keys' do
        config2 = { users: %w(admin) }
        config.update!(config2)
        expect(config.users).to eql(config2[:users])
      end

      it 'updates keys value from a Hash with symbol keys' do
        config2 = { keys: [create_ssl_key.public_key.to_pem] }
        config.update!(config2)
        expect(config.keys).to eql(config2[:keys])
      end

      it 'updates multiple values from a Hash with different kind of keys' do
        config2 = {
          'partial_search' => false,
          client_search: [],
          node_search: [],
          keys: [create_ssl_key.public_key.to_pem]
        }
        config.update!(config2)

        expect(config.partial_search).to eql(config2['partial_search'])
        expect(config.client_search).to eql(config2[:client_search])
        expect(config.node_search).to eql(config2[:node_search])
        expect(config.keys).to eql(config2[:keys])
      end
    end # describe #update!

    context '#[]' do
      it 'reads a configuration variable' do
        config1 = config_class.new(partial_search: true)
        expect(config1[:partial_search]).to eql(true)
      end

      it 'ignores non existing configuration options' do
        config1 = config_class.new
        expect { config1[:random_config_options] }.not_to raise_error
      end
    end # context #[]

    context '#[]=' do
      it 'writes a configuration variable' do
        config1 = config_class.new(partial_search: false)
        expect(config1[:partial_search]).to eql(false)
        config1[:partial_search] = true
        expect(config1[:partial_search]).to eql(true)
      end

      it 'ignores non existing configuration options' do
        config1 = config_class.new
        expect { config1[:random_config_options] = 5 }.not_to raise_error
      end
    end # context #[]=
  end # describe Chef::EncryptedAttribute::Config instance
end # describe Chef::EncryptedAttribute::Config
