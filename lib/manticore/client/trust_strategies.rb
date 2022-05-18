module Manticore
  class Client
    ##
    # TrustStrategies is a utility module that provides helpers for
    # working with org.apache.http.conn.ssl.TrustStrategy
    module TrustStrategies
      # Coerces to org.apache.http.conn.ssl.TrustStrategy, allowing nil pass-through
      #
      # @overload coerce(coercible)
      #   @param coercible [nil|TrustStrategy]
      #   @return [nil,TrustStrategy]
      # @overload coerce(coercible)
      #   @param coercible [Proc<(Array<OpenSSL::X509::Certificate>,String)>:Boolean]
      #     A proc that accepts two arguments and returns a boolean value, and is effectively a
      #     Ruby-native implementation of `org.apache.http.conn.ssl.TrustStrategy#isTrusted`.
      #       @param cert_chain [Enumerable<OpenSSL::X509::Certificate>]: the peer's certificate chain
      #       @param auth_type [String]: the authentication type based on the client certificate
      #       @raise [OpenSSL::X509::CertificateError]: thrown if the certificate is not trusted or invalid
      #       @return [Boolean]: true if the certificate can be trusted without verification by the trust manager,
      #                          false otherwise.
      #   @example: CA Trusted Fingerprint
      #      ca_trusted_fingerprint = lambda do |cert_chain, type|
      #        cert_chain.lazy
      #                  .map(&:to_der)
      #                  .map(&::Digest::SHA256.method(:hexdigest))
      #                  .include?("324a87eebb19265ffb675dc345eb0f3b5d9de3f015159227a00fe552291d4cc4")
      #      end
      #      TrustStrategies.coerce(ca_trusted_fingerprint)
      def self.coerce(coercible)
        case coercible
        when org.apache.http.conn.ssl.TrustStrategy, nil then coercible
        when ::Proc                                      then CustomTrustStrategy.new(coercible)
        else fail(ArgumentError, "No implicit conversion of #{coercible} to #{self}")
        end
      end

      # Combines two possibly-nil TrustStrategies-coercible objects into a
      # single org.apache.http.conn.ssl.TrustStrategy, or to nil if both are nil.
      #
      # @param lhs [nil|TrustStrategie#coerce]
      # @param rhs [nil|TrustStrategies#coerce]
      # @return [nil,org.apache.http.conn.ssl.TrustStrategy]
      def self.combine(lhs, rhs)
        return coerce(rhs) if lhs.nil?
        return coerce(lhs) if rhs.nil?

        CombinedTrustStrategy.new(coerce(lhs), coerce(rhs))
      end
    end

    ##
    # @api private
    # A CombinedTrustStrategy can be used to bypass the Trust Manager if
    # *EITHER* TrustStrategy trusts the provided certificate chain.
    # @see TrustStrategies::combine
    class CombinedTrustStrategy
      include org.apache.http.conn.ssl.TrustStrategy

      ##
      # @api private
      # @see TrustStrategies::combine
      def initialize(lhs, rhs)
        @lhs = lhs
        @rhs = rhs
        super()
      end

      ##
      # @override (see org.apache.http.conn.ssl.TrustStrategy#isTrusted)
      def trusted?(chain, type)
        @lhs.trusted?(chain, type) || @rhs.trusted?(chain, type)
      end
    end


    ##
    # @api private
    # A CustomTrustStrategy is an org.apache.http.conn.ssl.TrustStrategy
    # defined with a proc that uses Ruby OpenSSL::X509::Certificates
    # @see TrustStrategies::coerce(Proc)
    class CustomTrustStrategy
      include org.apache.http.conn.ssl.TrustStrategy

      ##
      # @see TrustStrategies.coerce(Proc)
      def initialize(proc)
        fail(ArgumentError, "2-arity proc required") unless proc.arity == 2
        @trust_strategy = proc
      end

      CONVERT_JAVA_CERTIFICATE_TO_RUBY = -> (java_cert) { ::OpenSSL::X509::Certificate.new(java_cert.encoded) }
      private_constant :CONVERT_JAVA_CERTIFICATE_TO_RUBY

      ##
      # @override (see org.apache.http.conn.ssl.TrustStrategy#isTrusted)
      def trusted?(java_chain, type)
        @trust_strategy.call(java_chain.lazy.map(&CONVERT_JAVA_CERTIFICATE_TO_RUBY), String.new(type))
      rescue OpenSSL::X509::CertificateError => e
        raise java_certificate_exception(e)
      end

      private

      begin
        # Ruby exceptions can be converted to Throwable since JRuby 9.2
        Exception.new("sentinel").to_java(java.lang.Throwable)
        def java_certificate_exception(ruby_certificate_error)
          throwable = ruby_certificate_error.to_java(java.lang.Throwable)
          java.security.cert.CertificateException.new(throwable)
        end
      rescue TypeError
        def java_certificate_exception(ruby_certificate_error)
          message = ruby_certificate_error.message
          java.security.cert.CertificateException.new(message)
        end
      end
    end
  end
end
