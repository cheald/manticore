module Manticore
  class Client
    include_package "org.apache.http.impl.client"
    include_package "org.apache.http.client.methods"
    include_package "org.apache.http.protocol"
    include_package "org.apache.http.entity"
    include_package "org.apache.http.client.entity"
    include_package "org.apache.http.message"

    def initialize(user_agent = "Manticore #{VERSION}")
      builder  = HttpClientBuilder.create
      builder.set_user_agent user_agent
      yield builder if block_given?
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

      case req
      when HttpPost, HttpPut, HttpPatch
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
    rescue Java::OrgApacheHttpClient::ClientProtocolException => e
      raise Manticore::ClientProtocolException.new(e.get_cause)
    end
  end
end