require 'thread'

module Manticore
  # General Timeout exception thrown for various Manticore timeouts
  class Timeout < ManticoreException; end

  # Core Manticore client, with a backing {http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/conn/PoolingHttpClientConnectionManager.html PoolingHttpClientConnectionManager}
  class Client
    include_package "org.apache.http.client.methods"
    include_package "org.apache.http.client.entity"
    include_package "org.apache.http.client.config"
    include_package "org.apache.http.config"
    include_package "org.apache.http.impl"
    include_package "org.apache.http.impl.client"
    include_package "org.apache.http.impl.conn"
    include_package "org.apache.http.entity"
    include_package "org.apache.http.message"
    include_package "org.apache.http.params"
    include_package "org.apache.http.protocol"
    include_package "java.util.concurrent"
    java_import 'java.net.UnknownHostException'
    java_import 'java.util.concurrent.TimeUnit'
    java_import 'java.util.concurrent.CountDownLatch'
    java_import 'java.util.concurrent.LinkedBlockingQueue'
    java_import 'javax.net.ssl.SSLHandshakeException'

    # The default maximum pool size for requests
    DEFAULT_MAX_POOL_SIZE   = 50

    # The default maximum number of threads per route that will be permitted
    DEFAULT_MAX_PER_ROUTE   = 10

    DEFAULT_REQUEST_TIMEOUT = 60
    DEFAULT_SOCKET_TIMEOUT  = 10
    DEFAULT_CONNECT_TIMEOUT = 10
    DEFAULT_MAX_REDIRECTS   = 5
    DEFAULT_EXPECT_CONTINUE = false
    DEFAULT_STALE_CHECK     = false

    # Create a new HTTP client with a backing request pool. if you pass a block to the initializer, the underlying
    # {http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/client/HttpClientBuilder.html HttpClientBuilder}
    # and {http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/config/RequestConfig.Builder.html RequestConfig.Builder}
    # will be yielded so that you can operate on them directly.
    #
    # @see http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/client/HttpClientBuilder.html HttpClientBuilder
    # @see http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/config/RequestConfig.Builder.html RequestConfig.Builder
    # @example  Simple instantiation and usage
    #   client = Manticore::Client.new
    #   client.get("http://www.google.com")
    #
    # @example Instantiation with a block
    #   client = Manticore::Client.new(socket_timeout: 5) do |http_client_builder, request_builder|
    #     http_client_builder.disable_redirect_handling
    #   end
    #
    # @param options [Hash] Client pool options
    # @option options [String]  user_agent                 The user agent used in requests.
    # @option options [Integer] pool_max           (50)    The maximum number of active connections in the pool
    # @option options [integer] pool_max_per_route (2)     Sets the maximum number of active connections for a given target endpoint
    # @option options [boolean] cookies            (true)  enable or disable automatic cookie management between requests
    # @option options [boolean] compression        (true)  enable or disable transparent gzip/deflate support
    # @option options [integer] request_timeout    (60)    Sets the timeout for requests. Raises Manticore::Timeout on failure.
    # @option options [integer] connect_timeout    (10)    Sets the timeout for connections. Raises Manticore::Timeout on failure.
    # @option options [integer] socket_timeout     (10)    Sets SO_TIMEOUT for open connections. A value of 0 is an infinite timeout. Raises Manticore::Timeout on failure.
    # @option options [integer] request_timeout    (60)    Sets the timeout for a given request. Raises Manticore::Timeout on failure.
    # @option options [integer] max_redirects      (5)     Sets the maximum number of redirects to follow.
    # @option options [boolean] expect_continue    (false) Enable support for HTTP 100
    # @option options [boolean] stale_check        (false) Enable support for stale connection checking. Adds overhead.
    def initialize(options = {})
      builder  = client_builder
      builder.set_user_agent options.fetch(:user_agent, "Manticore #{VERSION}")
      builder.disable_cookie_management unless options.fetch(:cookies, false)
      builder.disable_content_compression if options.fetch(:compression, true) == false

      # This should make it easier to reuse connections
      builder.disable_connection_state
      builder.set_connection_reuse_strategy DefaultConnectionReuseStrategy.new

      # socket_config = SocketConfig.custom.set_tcp_no_delay(true).build
      builder.set_connection_manager pool(options)

      request_config = RequestConfig.custom
      request_config.set_connection_request_timeout     options.fetch(:request_timeout, DEFAULT_REQUEST_TIMEOUT) * 1000
      request_config.set_connect_timeout                options.fetch(:connect_timeout, DEFAULT_CONNECT_TIMEOUT) * 1000
      request_config.set_socket_timeout                 options.fetch(:socket_timeout, DEFAULT_SOCKET_TIMEOUT) * 1000
      request_config.set_max_redirects                  options.fetch(:max_redirects, DEFAULT_MAX_REDIRECTS)
      request_config.set_expect_continue_enabled        options.fetch(:expect_continue, DEFAULT_EXPECT_CONTINUE)
      request_config.set_stale_connection_check_enabled options.fetch(:stale_check, DEFAULT_STALE_CHECK)
      # request_config.set_authentication_enabled         options.fetch(:use_auth, false)
      request_config.set_circular_redirects_allowed false

      yield builder, request_config if block_given?

      builder.set_default_request_config request_config.build
      @client = builder.build
      @options = options
      @async_requests = []
    end

    ### Sync methods

    # Perform a HTTP GET request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def get(url, options = {}, &block)
      request HttpGet, url, options, &block
    end

    # Perform a HTTP PUT request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def put(url, options = {}, &block)
      request HttpPut, url, options, &block
    end

    # Perform a HTTP HEAD request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def head(url, options = {}, &block)
      request HttpHead, url, options, &block
    end

    # Perform a HTTP POST request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def post(url, options = {}, &block)
      request HttpPost, url, options, &block
    end

    # Perform a HTTP DELETE request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def delete(url, options = {}, &block)
      request HttpDelete, url, options, &block
    end

    # Perform a HTTP OPTIONS request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def options(url, options = {}, &block)
      request HttpOptions, url, options, &block
    end

    # Perform a HTTP PATCH request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def patch(url, options = {}, &block)
      request HttpPatch, url, options, &block
    end

    ### Async methods

    # Queue an asynchronous HTTP GET request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_get(url, options = {}, &block)
      get url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP HEAD request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_head(url, options = {}, &block)
      head url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP PUT request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_put(url, options = {}, &block)
      put url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP POST request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_post(url, options = {}, &block)
      post url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP DELETE request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_delete(url, options = {}, &block)
      delete url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP OPTIONS request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_options(url, options = {}, &block)
      options url, options.merge(async: true), &block
    end

    # Queue an asynchronous HTTP PATCH request
    # @param  url [String] URL to request
    # @param  options [Hash]
    # @option options [Hash] params  Hash of options to pass as request parameters
    # @option options [Hash] body    Hash of options to pass as request body
    # @option options [Hash] headers Hash of options to pass as additional request headers
    #
    # @return [Response]
    def async_patch(url, options = {}, &block)
      patch url, options.merge(async: true), &block
    end

    # Remove all pending asynchronous requests.
    #
    # @return nil
    def clear_pending
      @async_requests.clear
      nil
    end

    # Execute all queued async requests
    #
    # @return [Array] An array of the responses from the requests executed.
    def execute!
      result = @executor.invoke_all(@async_requests).map(&:get)
      @async_requests.clear
      result
    end

    protected

    def client_builder
      HttpClientBuilder.create
    end

    def pool_builder
      PoolingHttpClientConnectionManager.new
    end

    def pool(options = {})
      @pool ||= begin
        @max_pool_size = options.fetch(:pool_max, DEFAULT_MAX_POOL_SIZE)
        cm = pool_builder
        cm.set_default_max_per_route options.fetch(:pool_max_per_route, DEFAULT_MAX_PER_ROUTE)
        cm.set_max_total @max_pool_size
        Thread.new {
          loop {
            cm.closeExpiredConnections
            sleep 5000
          }
        }
        cm
      end
    end

    def create_executor_if_needed
      return @executor if @executor
      @executor = Executors.new_cached_thread_pool
      at_exit { @executor.shutdown }
    end

    def request(klass, url, options, &block)
      req = request_from_options(klass, url, options)
      if options.delete(:async)
        async_request req, &block
      else
        sync_request req, &block
      end
    end

    def async_request(request, &block)
      create_executor_if_needed
      response = AsyncResponse.new(@client, request, BasicHttpContext.new, block)
      @async_requests << response
      response
    end

    def sync_request(request, &block)
      response = Response.new(request, BasicHttpContext.new, block)
      begin
        @client.execute request, response, response.context
      rescue Java::JavaNet::SocketTimeoutException, Java::OrgApacheHttpConn::ConnectTimeoutException, Java::OrgApacheHttp::NoHttpResponseException => e
        raise Manticore::Timeout.new(e.get_cause)
      rescue Java::OrgApacheHttpClient::ClientProtocolException, SSLHandshakeException => e
        raise Manticore::ClientProtocolException.new(e.get_cause)
      rescue UnknownHostException => e
        raise Manticore::ResolutionFailure.new(e.get_cause)
      end
    end

    def uri_from_url_and_options(url, options)
      uri = Addressable::URI.parse url
      if options[:query]
        uri.query_values ||= {}
        case options[:query]
        when Hash
          uri.query_values.merge! options[:query]
        when String
          uri.query_values.merge! CGI.parse(options[:query])
        else
          raise "Queries must be hashes or strings"
        end
      end
      uri
    end

    def request_from_options(klass, url, options)
      req = klass.new uri_from_url_and_options(url, options).to_s

      if ( options[:params] || options[:body] ) &&
         ( req.instance_of?(HttpPost) || req.instance_of?(HttpPatch) || req.instance_of?(HttpPut) )
        if options[:params]
          req.set_entity hash_to_entity(options[:params])
        elsif options[:body]
          req.set_entity StringEntity.new(options[:body])
        end
      end

      if options[:headers]
        options[:headers].each {|k, v| req.set_header k, v }
      end

      req
    end

    def hash_to_entity(hash)
      pairs = hash.map do |key, val|
        BasicNameValuePair.new(key, val)
      end
      UrlEncodedFormEntity.new(pairs)
    end
  end
end