module Manticore
  class AsyncResponse < Response
    java_import 'java.util.concurrent.Callable'
    include Callable
    attr_accessor :exception

    def initialize(client, request, context, body_handler_block)
      @client = client
      @handlers = {
        success:   ->(request){},
        failure:   ->(ex){},
        cancelled: ->{}
      }
      body_handler_block.call(self) if body_handler_block
      super request, context, nil
    end

    def call
      begin
        @client.execute @request, self, @context
      rescue Java::JavaNet::SocketTimeoutException, Java::OrgApacheHttpConn::ConnectTimeoutException, Java::OrgApacheHttp::NoHttpResponseException => e
        @handlers[:failure].call( Manticore::Timeout.new(e.get_cause) )
      rescue Java::OrgApacheHttpClient::ClientProtocolException => e
        @handlers[:failure].call( Manticore::ClientProtocolException.new(e.get_cause) )
      end
    end

    # Handler for success responses
    def on_success(&block)
      @handlers[:success] = block
      self
    end
    alias_method :success, :on_success

    # Handler for failure responses
    def on_failure(&block)
      @handlers[:failure] = block
      self
    end
    alias_method :failure, :on_failure

    # Handler for cancelled requests
    def on_cancelled(&block)
      @handlers[:cancelled] = block
      self
    end
    alias_method :cancelled, :on_cancelled
    alias_method :cancellation, :on_cancelled

    private

    def handle_response(response)
      begin
        @response = response
        @code     = response.get_status_line.get_status_code
        @headers  = Hash[* response.get_all_headers.flat_map {|h| [h.get_name.downcase, h.get_value]} ]
        @handlers[:success].call(self, @request)
      rescue => e
        @exception = e
      end
    end
  end
end