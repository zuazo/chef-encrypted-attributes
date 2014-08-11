def ruby_gte_19?
  RUBY_VERSION >= '1.9'
end

def ruby_gte_20?
  RUBY_VERSION.to_f >= 2.0
end

def ruby_lt_20?
  !ruby_gte_20?
end

def openssl_gte_101?
  OpenSSL::OPENSSL_VERSION_NUMBER >= 10001000
end

def openssl_lt_101?
  !openssl_gte_101?
end
