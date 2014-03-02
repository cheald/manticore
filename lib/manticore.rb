require 'java'
require 'uri'
require 'cgi'
require 'cgi/cookie'

# 4.3.x
require_relative "./jar/httpcore-4.3.1"
require_relative "./jar/httpclient-4.3.2-patched"
require_relative "./jar/commons-logging-1.1.3"
require_relative "./jar/commons-codec-1.6.jar"
require_relative "./jar/manticore-ext"

org.manticore.Manticore.new.load(JRuby.runtime, false)

require_relative "./manticore/version"
require "addressable/uri"

# HTTP client with the body of a lion and the head of a man. Or more simply, the power of Java
# with the beauty of Ruby.
module Manticore
  # General base class for all Manticore exceptions
  class ManticoreException < StandardError; end

  # Exception thrown if you attempt to read from a closed Response stream
  class StreamClosedException < ManticoreException; end

  # Friendly wrapper for various Java ClientProtocolExceptions
  class ClientProtocolException < ManticoreException; end

  # DNS resolution failure
  class ResolutionFailure < ManticoreException; end

  # Socket breaks, etc
  class SocketException < ManticoreException; end

  require_relative './manticore/client'
  require_relative './manticore/response'
  require_relative './manticore/stubbed_response'
  require_relative './manticore/cookie'
  require_relative './manticore/facade'

  include Facade
  include_http_client
end
