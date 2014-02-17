module Manticore
  # AsyncResponse is a runnable/future that encapsulates a request to be run asynchronously. It is created by Client#async_* calls.
  class AsyncResponse < Response
    java_import 'java.util.concurrent.Callable'

    include Callable

    # Creates a new AsyncResponse. The response is not realized until the client associated
    # with this response calls #execute!
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

    # @private
    # Implementation of Callable#call
    def call
      begin
        @client.execute @request, self, @context
      rescue Java::JavaNet::SocketTimeoutException, Java::OrgApacheHttpConn::ConnectTimeoutException, Java::OrgApacheHttp::NoHttpResponseException => e
        @handlers[:failure].call( Manticore::Timeout.new(e.get_cause) )
      rescue Java::OrgApacheHttpClient::ClientProtocolException => e
        @handlers[:failure].call( Manticore::ClientProtocolException.new(e.get_cause) )
      end
    end

    # Set handler for success responses
    # @param block Proc which will be invoked on a successful response. Block will receive |response, request|
    #
    # @return self
    def on_success(&block)
      @handlers[:success] = block
      self
    end
    alias_method :success, :on_success

    # Set handler for failure responses
    # @param block Proc which will be invoked on a on a failed response. Block will receive an exception object.
    #
    # @return self
    def on_failure(&block)
      @handlers[:failure] = block
      self
    end
    alias_method :failure, :on_failure
    alias_method :fail,    :on_failure

    # Set handler for cancelled requests
    # @param block Proc which will be invoked on a on a cancelled response.
    #
    # @return self
    def on_cancelled(&block)
      @handlers[:cancelled] = block
      self
    end
    alias_method :cancelled,       :on_cancelled
    alias_method :cancellation,    :on_cancelled
    alias_method :on_cancellation, :on_cancelled

    private

    # @private
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