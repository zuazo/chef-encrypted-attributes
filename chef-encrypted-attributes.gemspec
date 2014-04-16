$:.push File.expand_path('../lib', __FILE__)
require 'chef/encrypted_attribute/version'
chef_version = ENV.key?('CHEF_VERSION') ? "#{ENV['CHEF_VERSION']}" : ['>= 0.9.0']

Gem::Specification.new do |s|
  s.name = 'chef-encrypted-attributes'
  s.version = ::Chef::EncryptedAttribute::VERSION
  s.date = '2014-04-04'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Chef Encrypted Attribute'
  s.description = 'Chef plugin to support Encrypted Attributes using the node and client keys'
  s.license = 'Apache-2.0'
  s.authors = ['Onddo Labs, SL.']
  s.email = 'team@onddo.com'
  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob('lib/**/*')
  s.test_files = Dir.glob('{test,spec,features}/*')

  # Rake 10.2 drops Ruby 1.8 support
  s.add_development_dependency("rake", "~> 10.1.0")

  s.add_development_dependency 'chef', chef_version
  s.add_development_dependency 'chef-zero'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec-core'
  s.add_development_dependency 'rspec-expectations'
  s.add_development_dependency 'rspec-mocks'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'simplecov'
end