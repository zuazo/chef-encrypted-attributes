#!/usr/bin/env rake
# encoding: utf-8

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'spec'
  test.pattern = 'spec/**/test_*.rb'
  test.verbose = true
end

task :default => :test
