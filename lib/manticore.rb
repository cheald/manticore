require 'java'
require "ext/httpcore-4.3"
require "ext/httpclient-4.3.1"
require "ext/commons-logging-1.1.3"
require "manticore/version"

module Manticore
  class ManticoreException < StandardError; end
  class UnhandledResponseCode < ManticoreException; end
  class StreamClosedException < ManticoreException; end
  class ClientProtocolException < ManticoreException; end

  require 'manticore/client'
  require 'manticore/response'
end
