class Chef
  class EncryptedAttribute
    module Yajl
      def self.load_requirement(chef_version)
        if Gem::Requirement.new('< 11.13').satisfied_by?(
          Gem::Version.new(chef_version)
        )
          require 'yajl'
          ::Yajl
        else
          require 'ffi_yajl'
          ::FFI_Yajl
        end
      end
    end
  end
end
