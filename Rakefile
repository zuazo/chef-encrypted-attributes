# encoding: UTF-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

# More info at https://github.com/jimweirich/rake/blob/master/doc/rakefile.rdoc

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

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

desc 'Generate Ruby documentation'
task :yard do
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.stats_options = %w(--list-undoc)
  end
end

task doc: %w(yard)

desc 'Run RuboCop style checks'
task :rubocop do
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

desc 'Run all style checks'
task style: %w(rubocop)

{
  test: '{unit,integration}',
  unit: 'unit',
  integration: 'integration',
  benchmark: 'benchmark'
}.each do |test, dir|
  Rake::TestTask.new(test) do |t|
    t.libs << 'lib' << 'spec'
    t.pattern = "spec/#{dir}/**/*.rb"
    t.verbose = true
  end
end

if RUBY_VERSION < '1.9.3'
  # Integration tests are broken in 1.9.2 due to a chef-zero bug:
  #   https://github.com/opscode/chef-zero/issues/65
  # RuboCop require Ruby 1.9.3.
  task default: %w(unit)
else
  task default: %w(style test)
end
