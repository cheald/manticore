require 'java'
require_relative "./jar/httpcore-4.3.1"
require_relative "./jar/httpclient-4.3.2"
require_relative "./jar/commons-logging-1.1.3"
require "manticore/version"
require "addressable/uri"

module Manticore
  class ManticoreException < StandardError; end
  class UnhandledResponseCode < ManticoreException; end
  class StreamClosedException < ManticoreException; end
  class ClientProtocolException < ManticoreException; end

  require 'manticore/client'
  require 'manticore/response'
end
