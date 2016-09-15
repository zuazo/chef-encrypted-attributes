# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
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

module BenchmarkHelpers
  # Benchmark test helpers related with EncryptedAttribute class
  module EncryptedAttribute
    def benchmark_each_version(desc, &block)
      %w(0 1 2).each do |version|
        Chef::Config[:encrypted_attributes][:version] = version
        benchmark_it "#{desc} (v=#{version})" do
          instance_eval(&block)
        end
        Chef::Config[:encrypted_attributes].delete(:version)
      end
    end
  end
end
