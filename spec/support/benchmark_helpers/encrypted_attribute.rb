module BenchmarkHelpers::EncryptedAttribute

  def benchmark_each_version(desc, &block)
    %w{0 1}.each do |version|
      Chef::Config[:encrypted_attributes][:version] = version
      benchmark_it "#{desc} (v=#{version})" do
        instance_eval(&block)
      end
    end
  end

end
