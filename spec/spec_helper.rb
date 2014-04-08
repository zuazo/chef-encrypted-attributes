require 'simplecov'
if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start do
  add_filter '/spec/'
end

require 'chef/encrypted_attribute'

require 'rspec/autorun'

RSpec.configure do |config|
  config.order = 'random'

  config.color_enabled = true
  config.tty = true
end
