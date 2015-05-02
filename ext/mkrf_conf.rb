# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2015 Onddo Labs, SL. (www.onddo.com)
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

# Conditional gem dependency installation within a gemspec.
#
# Based on:
# * http://www.programmersparadox.com/2012/05/21
#     /gemspec-loading-dependent-gems-based-on-the-users-system/
# * https://www.tiredpixel.com/2014/01/05
#     /curses-conditional-ruby-gem-installation-within-a-gemspec/

require 'rubygems/dependency_installer'

di = Gem::DependencyInstaller.new

begin
  if RUBY_VERSION < '1.9.3'
    puts "Installing mixlib-shellout < 1.6.1 because Ruby #{RUBY_VERSION}"
    di.install 'mixlib-shellout', '< 1.6.1'
  end
  if RUBY_VERSION < '2'
    puts "Installing highline < 1.7 because Ruby #{RUBY_VERSION}"
    di.install 'highline', '< 1.7'
    puts "Installing ohai < 8 because Ruby #{RUBY_VERSION}"
    di.install 'ohai', '< 8'
  end
rescue => e
  warn "#{$PROGRAM_NAME}: #{e}"
  exit!
end

puts 'Writing fake Rakefile'
# Write fake Rakefile for rake since Makefile isn't used
File.open(File.join(File.dirname(__FILE__), 'Rakefile'), 'w') do |f|
  f.write("task :default\n")
end
