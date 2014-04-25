require 'rspec/autorun'
require 'chef_zero/rspec'
require 'chef/encrypted_attribute'

require 'support/silent_formatter'
RSpec.configure do |config|
  config.reset
  config.formatter = 'SilentFormatter'
end

require 'support/benchmark_helpers'
include BenchmarkHelpers
require 'support/benchmark_helpers/encrypted_attribute'
include BenchmarkHelpers::EncryptedAttribute
