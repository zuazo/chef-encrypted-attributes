require 'simplecov'
if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start

require 'chef/encrypted_attribute'

require 'rspec/autorun'

RSpec.configure do |config|
  config.order = 'random'

  config.color_enabled = true
  config.tty = true
end
