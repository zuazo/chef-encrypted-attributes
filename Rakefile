#!/usr/bin/env rake
# encoding: utf-8

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

{
  :test => '**',
  :unit => 'unit',
  :integration => 'integration',
}.each do |test, dir|
  Rake::TestTask.new(test) do |test|
    test.libs << 'lib' << 'spec'
    test.pattern = "spec/#{dir}/test_*.rb"
    test.verbose = true
  end
end

task :default => :test
