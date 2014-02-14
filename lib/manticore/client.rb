require 'thread'

module Manticore
  class Timeout < StandardError; end
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

    def initialize(options = {})
      builder  = HttpClientBuilder.create
      builder.set_user_agent options.fetch(:user_agent, "Manticore #{VERSION}")
      builder.disable_cookie_management unless options.fetch(:cookies, false)
      builder.disable_content_compression if options.fetch(:compression, true) == false

      # This should make it easier to reuse connections
      builder.disable_connection_state
      builder.set_connection_reuse_strategy DefaultConnectionReuseStrategy.new

      # socket_config = SocketConfig.custom.set_tcp_no_delay(true).build
      builder.set_connection_manager pool(options)

      request_config = RequestConfig.custom
      request_config.set_connection_request_timeout     options.fetch(:request_timeout, 60) * 1000
      request_config.set_connect_timeout                options.fetch(:connect_timeout, 10) * 1000
      request_config.set_socket_timeout                 options.fetch(:socket_timeout, 10) * 1000
      request_config.set_max_redirects                  options.fetch(:max_redirects, 5)
      request_config.set_expect_continue_enabled        options.fetch(:expect_continue, false)
      request_config.set_stale_connection_check_enabled options.fetch(:stale_check, false)
      request_config.set_authentication_enabled         options.fetch(:use_auth, false)
      request_config.set_circular_redirects_allowed false

      yield [builder, request_config] if block_given?

      builder.set_default_request_config request_config.build
      @client = builder.build
    end

    def get(url, options = {}, &block)
      request HttpGet, url, options, &block
    end

    def put(url, options = {}, &block)
      request HttpPut, url, options, &block
    end

    def head(url, options = {}, &block)
      request HttpHead, url, options, &block
    end

    def post(url, options = {}, &block)
      request HttpPost, url, options, &block
    end

    def delete(url, options = {}, &block)
      request HttpDelete, url, options, &block
    end

    def options(url, options = {}, &block)
      request HttpOptions, url, options, &block
    end

    def patch(url, options = {}, &block)
      request HttpPatch, url, options, &block
    end

    private

    def pool(options = {})
      @pool ||= begin
        cm = PoolingHttpClientConnectionManager.new
        cm.set_default_max_per_route options.fetch(:pool_max_per_route, 8)
        cm.set_max_total options.fetch(:pool_max, 64)
        Thread.new {
          loop {
            cm.closeExpiredConnections
            sleep 5000
          }
        }
        cm
      end
    end

    def request_from_options(klass, url, options)
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

      req = klass.new(uri.to_s)

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

    def request(klass, url, options, &block)
      req = request_from_options(klass, url, options)
      response = Response.new(req, BasicHttpContext.new, block)
      @client.execute req, response, response.context
      response
    rescue Java::JavaNet::SocketTimeoutException, Java::OrgApacheHttpConn::ConnectTimeoutException, Java::OrgApacheHttp::NoHttpResponseException => e
      raise Manticore::Timeout.new(e.get_cause)
    rescue Java::OrgApacheHttpClient::ClientProtocolException => e
      raise Manticore::ClientProtocolException.new(e.get_cause)
    end
  end
end