require 'simplecov'
if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end
SimpleCov.start

require 'chef/encrypted_attribute'

require 'rspec/autorun'
