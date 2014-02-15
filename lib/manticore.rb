require 'java'
require_relative "./jar/httpcore-4.3.1"
require_relative "./jar/httpclient-4.3.2"
require_relative "./jar/commons-logging-1.1.3"
require "manticore/version"
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

  require 'manticore/client'
  require 'manticore/response'
end
