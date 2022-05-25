require "java"
require "uri"
require "cgi"

require_relative "./manticore_jars.rb"
require_relative "./org/manticore/manticore-ext"

if defined? JRuby::Util.load_ext
  JRuby::Util.load_ext 'org.manticore.Manticore'
else
  org.manticore.Manticore.new.load(JRuby.runtime, false)
end

require_relative "./manticore/version"

# HTTP client with the body of a lion and the head of a man. Or more simply, the power of Java
# with the beauty of Ruby.
module Manticore
  # General base class for all Manticore exceptions
  class ManticoreException < StandardError
    def initialize(arg = nil)
      case arg
      when nil
        @_cause = nil
        super()
      when java.lang.Throwable
        @_cause = arg
        super(arg.message)
      else
        @_cause = nil
        super(arg)
      end
    end

    # @return cause which is likely to be a Java exception
    # @overload Exception#cause
    def cause
      @_cause || super
    end
  end

  # Exception thrown if you attempt to read from a closed Response stream
  class StreamClosedException < ManticoreException; end

  # Friendly wrapper for various Java ClientProtocolExceptions
  class ClientProtocolException < ManticoreException; end

  # DNS resolution failure
  class ResolutionFailure < ManticoreException; end

  # Is something flat out malformed (bad port number?)
  class InvalidArgumentException < ManticoreException; end

  # The client has been closed so it's no longer usable
  class ClientStoppedException < ManticoreException; end

  # Socket breaks, etc
  class SocketException < ManticoreException; end

  # General Timeout exception thrown for various Manticore timeouts
  class Timeout < ManticoreException; end
  class SocketTimeout < Timeout; end
  class ConnectTimeout < Timeout; end

  # Did we miss an exception? We may still want to catch it
  class UnknownException < ManticoreException; end

  require_relative "./manticore/java_extensions"
  require_relative "./manticore/client/proxies"
  require_relative "./manticore/client/trust_strategies"
  require_relative "./manticore/client"
  require_relative "./manticore/response"
  require_relative "./manticore/stubbed_response"
  require_relative "./manticore/cookie"
  require_relative "./manticore/facade"

  include Facade
  include_http_client

  def self.disable_httpcomponents_logging!
    props = Java::JavaLang::System.properties
    props.setProperty("org.apache.commons.logging.Log", "org.apache.commons.logging.impl.SimpleLog")
    props.setProperty("org.apache.commons.logging.simplelog.log.org.apache.http", "error")
  end
end
