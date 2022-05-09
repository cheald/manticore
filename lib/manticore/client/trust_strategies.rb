module Manticore
  class Client
    module TrustStrategiesInterface
      java_import org.apache.http.conn.ssl.TrustStrategy
      include TrustStrategy

      # Coerces to org.apache.http.conn.ssl.TrustStrategy, allowing nil pass-through
      #
      # @overload coerce(coercible)
      #   @param coercible [nil|TrustStrategy]
      #   @return [nil,TrustStrategy]
      # @overload coerce(coercible)
      #   @param coercible [Proc<(Array<OpenSSL::X509::Certificate>,String)>:Boolean]
      #     A proc that accepts two arguments and returns a boolean value.
      #     Expects a proc that operates on a pair of parameters:
      #       @param cert_chain [Enumerable<OpenSSL::X509::Certificate>]: the peer's certificate chain
      #       @param auth_type [String]: the authentication type based on the client certificate
      #       @return [Boolean]: true if the certificate can be trusted without verification by the trust manager,
      #                        false otherwise.
      #   @example: CA Trusted Fingerprint
      #      ca_trusted_fingerprint = lambda do |cert_chain, type|
      #        cert_chain.lazy
      #                  .map(&:to_der)
      #                  .map(&::Digest::SHA256.method(:hexdigest))
      #                  .include?("324a87eebb19265ffb675dc345eb0f3b5d9de3f015159227a00fe552291d4cc4")
      #      end
      #      TrustStrategiesInterface.coerce(ca_trusted_fingerprint)
      def self.coerce(coercible)
        case coercible
        when TrustStrategy, nil then coercible
        when ::Proc             then CustomTrustStrategy.new(coercible)
        else fail(ArgumentError, "No implicit conversion of #{coercible} to #{self}")
        end
      end

      # Combines two possibly-nil TrustStrategiesInterface-coercible objects into a
      # single TrustStrategy, or to nil if both are nil.
      #
      # @param lhs [nil|TrustStrategiesInterface]
      # @param rhs [nil|TrustStrategiesInterface]
      # @return [nil,TrustStrategiesInterface]
      def self.combine(lhs, rhs)
        return coerce(rhs) if lhs.nil?
        return coerce(lhs) if rhs.nil?

        CombinedTrustStrategy.new(lhs,rhs)
      end
    end

    ##
    # @api private
    # A CombinedTrustStrategy can be used to bypass the Trust Manager if
    # *EITHER* TrustStrategy trusts the provided certificate chain.
    class CombinedTrustStrategy
      include TrustStrategiesInterface

      ##
      # @api private
      # @see TrustStrategiesInterface::combine
      def initialize(lhs, rhs)
        @lhs = lhs
        @rhs = rhs
        super()
      end

      def trusted?(chain, type)
        @lhs.trusted?(chain, type) || @rhs.trusted?(chain, type)
      end
    end


    ##
    # @api private
    # A CustomTrustStrategy is an org.apache.http.conn.ssl.TrustStrategy
    # defined with a proc that uses Ruby OpenSSL::X509::Certificates
    # @see TrustStrategiesInterface::coerce(Proc)
    class CustomTrustStrategy
      include TrustStrategiesInterface

      ##
      # @see TrustStrategiesInterface.coerce(Proc)
      def initialize(proc)
        fail(ArgumentError, "2-arity proc required") unless proc.arity == 2
        @trust_strategy = proc
      end

      CONVERT_JAVA_CERTIFICATE_TO_RUBY = -> (java_cert) { ::OpenSSL::X509::Certificate.new(java_cert.encoded) }
      private_constant :CONVERT_JAVA_CERTIFICATE_TO_RUBY

      def trusted?(java_chain, type)
        return !!@trust_strategy.call(java_chain.lazy.map(&CONVERT_JAVA_CERTIFICATE_TO_RUBY), type)
      end

      private

      def ruby_cert(java_cert)
        ::OpenSSL::X509::Certificate.new(java_cert.encoded)
      end
    end
  end
end
