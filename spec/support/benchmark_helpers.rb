# encoding: UTF-8
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

require 'benchmark'

# Benchmark tests helpers
module BenchmarkHelpers
  def benchmark_caption
    Benchmark.bm(50) {} # print CAPTION
  end

  def benchmark_it(desc, &block)
    Benchmark.benchmark('', 50) do |x|
      it desc do
        x.report(desc) do
          100.times { instance_eval(&block) }
        end
      end
    end
  end
end
