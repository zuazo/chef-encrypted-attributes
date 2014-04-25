require 'benchmark'

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
