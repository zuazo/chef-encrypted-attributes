$:.push File.expand_path('../lib', __FILE__)
require 'chef/encrypted_attribute/version'
chef_version = ENV.key?('CHEF_VERSION') ? "#{ENV['CHEF_VERSION']}" : ['>= 11.0.0']

Gem::Specification.new do |s|
  s.name = 'chef-encrypted-attributes'
  s.version = ::Chef::EncryptedAttribute::VERSION
  s.date = '2014-05-20'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Chef Encrypted Attributes'
  s.description = 'Chef plugin to add Node encrypted attributes support using client keys'
  s.license = 'Apache-2.0'
  s.authors = ['Onddo Labs, SL.']
  s.email = 'team@onddo.com'
  s.homepage = 'http://onddo.github.io/chef-encrypted-attributes'
  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md API.md INTERNAL.md TESTING.md TODO.md CHANGELOG.md) + Dir.glob('lib/**/*')
  s.test_files = Dir.glob('{test,spec,features}/*')
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.2')

  s.add_dependency 'yajl-ruby', '~> 1.1'
  s.add_dependency 'chef', chef_version

  if RUBY_VERSION < '1.9'
    s.add_development_dependency 'rake', '< 10.2'
   # s.add_development_dependency 'mime-types', '< 2.0'
  end
  s.add_development_dependency 'chef-zero'
  s.add_development_dependency 'rspec-core', '~> 2.14'
  s.add_development_dependency 'rspec-expectations', '~> 2.14'
  s.add_development_dependency 'rspec-mocks', '~> 2.14'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'simplecov'
end
