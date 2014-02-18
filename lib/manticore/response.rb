module Manticore
  # Implementation of {http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/ResponseHandler.html ResponseHandler} which serves
  # as a Ruby proxy for HTTPClient responses.
  #
  # @!attribute [r] headers
  #   @return [Hash] Headers from this response
  # @!attribute [r] code
  #   @return [Integer] Response code from this response
  # @!attribute [r] context
  #   @return [HttpContext] Context associated with this request/response
  class Response
    include_package "org.apache.http.client"
    include_package "org.apache.http.util"
    include_package "org.apache.http.protocol"
    # java_import "org.manticore.EntityConverter"
    include ResponseHandler

    attr_reader :headers, :code, :context, :request

    # Creates a new Response
    #
    # @param  request            [HttpRequestBase] The underlying request object
    # @param  context            [HttpContext] The underlying HttpContext
    # @param  body_handler_block [Proc] And optional block to by yielded to for handling this response
    def initialize(request, context, body_handler_block)
      @request = request
      @context = context
      @handler_block = body_handler_block
    end

    # Implementation of {http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/ResponseHandler.html#handleResponse(org.apache.http.HttpResponse) ResponseHandler#handleResponse}
    # @param  response [Response] The underlying Java Response object
    def handle_response(response)
      @response = response
      @code     = response.get_status_line.get_status_code
      @headers  = Hash[* response.get_all_headers.flat_map {|h| [h.get_name.downcase, h.get_value]} ]
      if @handler_block
        @handler_block.call(self)
      else
        read_body
      end
      self
    end

    # Fetch the final resolved URL for this response
    #
    # @return [String]
    def final_url
      last_request = context.get_attribute ExecutionContext.HTTP_REQUEST
      last_host    = context.get_attribute ExecutionContext.HTTP_TARGET_HOST
      host         = last_host.to_uri
      url          = last_request.get_uri
      URI.join(host, url.to_s)
    end

    # Fetch the body content of this response.
    # This fetches the input stream in Ruby; this isn't optimal, but it's faster than
    # fetching the whole thing in Java then UTF-8 encoding it all into a giant Ruby string.
    #
    # This permits for streaming response bodies, as well.
    #
    # @example Streaming response
    #
    #     client.get("http://example.com/resource").on_success do |response|
    #       response.body do |chunk|
    #         # Do something with chunk, which is a parsed portion of the returned body
    #       end
    #     end
    #
    # @return [String] Reponse body
    def read_body(&block)
      @body ||= begin
        if entity = @response.get_entity
          EntityConverter.new.read_entity(entity, &block)
        end
      rescue Java::JavaIo::IOException, Java::JavaNet::SocketException, IOError => e
        raise StreamClosedException.new("Could not read from stream: #{e.message} (Did you forget to read #body from your block?)")
      end
    end
    alias_method :body, :read_body

    # Returns the length of the response body. Returns -1 if content-length is not present in the response.
    #
    # @return [Integer]
    def length
      (@headers["content-length"] || -1).to_i
    end

    private

    def encode(string, charset)
      return string if charset.nil?
      begin
        string.encode(charset)
      rescue Encoding::ConverterNotFoundError
        string.encode("utf-8")
      rescue
        string
      end
    end
  end
end