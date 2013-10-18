module Manticore
  class Response
    include_package "org.apache.http.client"
    include_package "org.apache.http.util"
    include_package "org.apache.http.protocol"
    include ResponseHandler

    attr_reader :headers, :code, :context

    def initialize(request, context, body_handler_block)
      @request = request
      @context = context
      @handler_block = body_handler_block
    end

    def handle_response(response)
      @response = response
      @code     = response.getStatusLine().getStatusCode()
      @headers  = Hash[* response.getAllHeaders().flat_map {|h| [h.get_name.downcase, h.get_value]} ]
      if @handler_block
        @handler_block.call(self)
      else
        read_body
      end
    end

    def final_url
      last_request = context.get_attribute ExecutionContext.HTTP_REQUEST
      last_host    = context.getAttribute ExecutionContext.HTTP_TARGET_HOST
      host         = last_host.to_uri
      url          = last_request.get_uri
      URI.join(host, url.to_s)
    end

    def read_body
      @body ||= begin
       entity = @response.getEntity()
       entity && EntityUtils.to_string(entity)
      rescue Java::JavaIo::IOException, Java::JavaNet::SocketException => e
        raise StreamClosedException.new("Could not read from stream: #{e.message} (Did you forget to read #body from your block?)")
      end
    end
    alias_method :body, :read_body

    def length
      (@headers["content-length"] || -1).to_i
    end
  end
end