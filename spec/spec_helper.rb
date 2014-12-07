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

require 'simplecov'
if ENV['TRAVIS'] && RUBY_VERSION >= '2.0'
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start do
  add_filter '/spec/'
end

require 'chef/encrypted_attributes'
require 'chef/exceptions'

require 'rspec/autorun'
require 'should_not/rspec'

require 'support/platform_helpers'
require 'support/chef_helpers'
require 'support/encrypted_attributes_helpers'

RSpec.configure do |config|
  config.order = 'random'

  config.color = true
  config.tty = true

  config.filter_run_excluding ruby_gte_19: true unless ruby_gte_19?
  config.filter_run_excluding ruby_gte_20: true unless ruby_gte_20?
  unless ruby_gte_20? && openssl_gte_101?
    config.filter_run_excluding ruby_gte_20_and_openssl_gte_101: true
  end
  config.filter_run_excluding openssl_lt_101: true unless openssl_lt_101?
  config.filter_run_excluding ruby_lt_20: true unless ruby_lt_20?

  config.include ChefHelpers
  config.include EncryptedAttributesHelpers
end
