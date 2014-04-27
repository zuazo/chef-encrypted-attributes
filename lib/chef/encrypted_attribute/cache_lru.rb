require 'chef/mixin/params_validate'

# Based on https://github.com/SamSaffron/lru_redux
class Chef
  class EncryptedAttribute
    class CacheLru < Hash
      include ::Chef::Mixin::ParamsValidate

      def initialize(size=nil)
        super
        max_size(size)
      end

      def max_size(arg=nil)
        set_or_return(
          :max_size,
          arg,
          :kind_of => [ Fixnum ],
          :default => 1024,
          :callbacks => begin
            { 'should not be lower that zero' => lambda { |x| x >= 0 } }
          end,
        )
        pop_tail unless arg.nil?
        @max_size
      end

      def [](key)
        if has_key?(key)
          val = super(key)
          self[key] = val
        else
          nil
        end
      end

      def []=(key, val)
        if max_size > 0 # unnecessary "if", small optimization?
          delete(key)
          super(key, val)
          pop_tail
        end
        val
      end

      protected

      def pop_tail
        while size > max_size
          delete(first[0])
        end
      end

    end
  end
end
