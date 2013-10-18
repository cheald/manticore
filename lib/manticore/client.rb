module Manticore
  class Client
    include_package "org.apache.http.impl.client"
    include_package "org.apache.http.client.methods"
    include_package "org.apache.http.protocol"

    def initialize(user_agent = "Manticore #{VERSION}")
      builder  = HttpClientBuilder.create
      builder.set_user_agent user_agent
      yield builder if block_given?
      @client = builder.build
    end

    def get(url, headers = {}, &block)
      request HttpGet.new(url.to_s), headers, &block
    end

    private

    def request(req, headers, &block)
      headers.each {|k, v| req.set_header k, v }
      response = Response.new(req, BasicHttpContext.new, block)
      @client.execute req, response, response.context
      puts "Returning response"
      response
    rescue Java::OrgApacheHttpClient::ClientProtocolException => e
      raise Manticore::ClientProtocolException.new(e.get_cause)
    end
  end
end