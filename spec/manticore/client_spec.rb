# encoding: utf-8
require 'spec_helper'

java_import 'org.apache.http.entity.mime.MultipartEntityBuilder'
java_import 'org.apache.http.entity.ContentType'

describe Manticore::Client do

  let(:client) { Manticore::Client.new }

  it "should fetch a URL and return a response" do
    client.get(local_server).should be_a Manticore::Response
  end

  it "should resolve redirections" do
    response = client.get(local_server, headers: {"X-Redirect" => "/foobar"})
    response.code.should == 200
    response.final_url.should == URI(local_server("/foobar"))
  end

  it "should accept custom headers" do
    response = client.get(local_server, headers: {"X-Custom-Header" => "Blaznotts"})
    json = JSON.load(response.body)
    json["headers"]["X-Custom-Header"].should == "Blaznotts"
  end

  it "should enable compression" do
    response = client.get(local_server)
    json = JSON.load(response.body)
    json["headers"].should have_key "Accept-Encoding"
    json["headers"]["Accept-Encoding"].should match("gzip")
  end

  it "should authenticate" do
    client.get(local_server("/auth")).code.should == 401
    client.get(local_server("/auth"), auth: {user: "user", pass: "pass"}).code.should == 200
  end

  it "should proxy" do
    j = JSON.parse(client.get(local_server("/proxy"), proxy: "http://localhost:55442").body)
    j["server_port"].should == 55442
    j["uri"]["port"].should == 55441
  end

  describe "with a custom user agent" do
    let(:client) { Manticore::Client.new user_agent: "test-agent/1.0" }

    it "should use the specified UA" do
      response = client.get(local_server("/"))
      json = JSON.load(response.body)
      expect(json["headers"]["User-Agent"]).to eq "test-agent/1.0"
    end
  end

  describe "ignore_ssl_validation (deprecated option)" do
    context "when on" do
      let(:client) { Manticore::Client.new ssl: {verify: false} }

      it "should not break on SSL validation errors" do
        expect { client.get("https://localhost:55444/").body }.to_not raise_exception
      end
    end

    context "when off" do
      let(:client) { Manticore::Client.new ssl: {verify: true} }

      it "should break on SSL validation errors" do
        expect { client.get("https://localhost:55444/").call }.to raise_exception(Manticore::ClientProtocolException)
      end
    end
  end

  describe 'ssl settings' do
    describe 'verify' do
      context 'default' do
        let(:client) { Manticore::Client.new }

        it "should break on SSL validation errors" do
          expect { client.get("https://localhost:55444/").call }.to raise_exception(Manticore::ClientProtocolException)
        end
      end

      context 'when on and no trust store is given' do
        let(:client) { Manticore::Client.new :ssl => {:verify => :strict} }

        it "should break on SSL validation errors" do
          expect { client.get("https://localhost:55444/").call }.to raise_exception(Manticore::ClientProtocolException)
        end
      end

      context 'when on and custom trust store is given' do
        let(:client) { Manticore::Client.new :ssl => {verify: :strict, truststore: File.expand_path("../../ssl/test_truststore", __FILE__), truststore_password: "test123"} }

        it "should verify the request and succeed" do
          expect { client.get("https://localhost:55444/").body }.to_not raise_exception
        end
      end

      context "when the client specifies a protocol list" do
        let(:client) { Manticore::Client.new :ssl => {verify: :strict, truststore: File.expand_path("../../ssl/test_truststore", __FILE__), truststore_password: "test123", protocols: ["TLSv1", "TLSv1.1", "TLSv1.2"]} }

        it "should verify the request and succeed" do
          expect { client.get("https://localhost:55444/").body }.to_not raise_exception
        end
      end

      context 'when on and custom trust store is given with the wrong password' do
        let(:client) { Manticore::Client.new :ssl => {verify: :strict, truststore: File.expand_path("../../ssl/test_truststore", __FILE__), truststore_password: "wrongpass"} }

        it "should fail to load the keystore" do
          expect { client.get("https://localhost:55444/").body }.to raise_exception(Java::JavaIo::IOException)
        end
      end

      context 'when ca_file is given' do
        let(:client) { Manticore::Client.new :ssl => {verify: :strict, ca_file: File.expand_path("../../ssl/ca_cert.crt", __FILE__) } }

        it "should verify the request and succeed" do
          expect { client.get("https://localhost:55444/").body }.to_not raise_exception
        end
      end

      context 'when client_cert and client_key are given' do
        let(:client) { Manticore::Client.new(
          :ssl => {
            verify: :strict,
            ca_file: File.expand_path("../../ssl/ca_cert.crt", __FILE__),
            client_cert: File.expand_path("../../ssl/client.crt", __FILE__),
            client_key: File.expand_path("../../ssl/client.key", __FILE__)
          })
        }

        it "should successfully auth requests" do
          expect(client.get("https://localhost:55445/").body).to match("hello")
        end
      end

      context 'when off' do
        let(:client) { Manticore::Client.new :ssl => {:verify => :none} }

        it "should not break on SSL validation errors" do
          expect { client.get("https://localhost:55444/").body }.to_not raise_exception
        end
      end

      context "against a server that verifies clients" do
        context "when client cert auth is provided" do
          let(:client) {
            options = {
              truststore: File.expand_path("../../ssl/test_truststore", __FILE__),
              truststore_password: "test123",
              keystore: File.expand_path("../../ssl/client.p12", __FILE__),
              keystore_password: ""
            }
            Manticore::Client.new :ssl => options.merge(verify: :strict)
          }

          it "should successfully auth requests" do
            expect(client.get("https://localhost:55445/").body).to match("hello")
          end
        end

        context "when client cert auth is not provided" do
          let(:client) {
            options = {
              truststore: File.expand_path("../../ssl/test_truststore", __FILE__),
              truststore_password: "test123"
            }
            Manticore::Client.new :ssl => options.merge(verify: :strict)
          }

          it "should fail the request" do
            # oraclejdk7 throws a SocketException here, oraclejdk8/openjdk7 throw ClientProtocolException
            expect { client.get("https://localhost:55445/").body }.to raise_exception(Manticore::ManticoreException)
          end
        end
      end
    end

    describe ":cipher_suites" do
      skip
    end

    describe ":protocols" do
      skip
    end
  end

  describe "lazy evaluation" do
    it "should not call synchronous requests by default" do
      req = client.get(local_server)
      req.should_not be_called
    end

    context "given a lazy request" do
      subject { client.get(local_server) }

      before do
        subject.should_not be_called
        subject.should_receive(:call).once.and_call_original
      end

      specify { expect { subject.body }.to change      { subject.called? } }
      specify { expect { subject.headers }.to change   { subject.called? } }
      specify { expect { subject.final_url }.to change { subject.called? } }
      specify { expect { subject.code }.to change      { subject.called? } }
      specify { expect { subject.length }.to change    { subject.called? } }
      specify { expect { subject.cookies }.to change   { subject.called? } }
    end

    it "should automatically call synchronous requests that pass a handler block" do
      req = client.get(local_server) {|r| }
      req.should be_called
    end

    it "should not call asynchronous requests even if a block is passed" do
      req = client.async.get(local_server) {|r| }
      req.should_not be_called
    end

    it "should not call asynchronous requests when on_success is passed" do
      req = client.async.get(local_server).on_success {|r| }
      req.should_not be_called
    end

    it "should call async requests on client execution" do
      req = client.async.get(local_server).on_success {|r| }
      expect { client.execute! }.to change { req.called? }.from(false).to(true)
    end
  end

  context "when client-wide cookie management is disabled" do
    let(:client) { Manticore::Client.new cookies: false }

    it "should persist cookies across multiple redirects from a single request" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].should be_nil
      response.headers["set-cookie"].should match(/1/)
    end

    it "should not persist cookies between requests" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].should be_nil
      response.headers["set-cookie"].should match(/1/)

      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].should be_nil
      response.headers["set-cookie"].should match(/1/)
    end
  end

  context "when client-wide cookie management is set to per-request" do
    let(:client) { Manticore::Client.new cookies: :per_request }

    it "should persist cookies across multiple redirects from a single request" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.headers["set-cookie"].should match(/2/)
      response.cookies["x"].first.value.should == "2"
    end

    it "should not persist cookies between requests" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.headers["set-cookie"].should match(/2/)
      response.cookies["x"].first.value.should == "2"

      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.headers["set-cookie"].should match(/2/)
      response.cookies["x"].first.value.should == "2"
    end
  end

  context "when client-wide cookie management is enabled" do
    let(:client) { Manticore::Client.new cookies: true }

    it "should persist cookies across multiple redirects from a single request" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].first.value.should == "2"
    end

    it "should persist cookies between requests" do
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].first.value.should == "2"

      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].first.value.should == "4"
    end
  end

  context "when compression is disabled" do
    let(:client) {
      Manticore::Client.new do |client, request_config|
        client.disable_content_compression
      end
    }

    it "should disable compression" do
      response = client.get(local_server)
      json = JSON.load(response.body)
      json["headers"]["Accept-Encoding"].should be_nil
    end
  end

  context "when no response charset is specified" do
    let(:content_type) { "text/plain" }

    it "should decode response bodies according to the content-type header" do
      client.get(local_server, headers: {"X-Content-Type" => content_type}).body.encoding.name.should == "ISO-8859-1"
    end
  end

  context "when an invalid response charset is specified" do
    let(:content_type) { "text/plain; charset=bogus" }

    it "should decode the content as UTF-8" do
      client.get(local_server, headers: {"X-Content-Type" => content_type}).body.encoding.name.should == "ISO-8859-1"
    end
  end

  context "when the response charset is UTF-8" do
    let(:content_type) { "text/plain; charset=utf-8" }

    it "should decode response bodies according to the content-type header" do
      client.get(local_server, headers: {"X-Content-Type" => content_type}).body.encoding.name.should == "UTF-8"
    end
  end

  describe "#get" do
    it "should work" do
      response = client.get(local_server)
      JSON.load(response.body)["method"].should == "GET"
    end

    it "send a query" do
      response = client.get local_server, query: {foo: "bar"}
      CGI.parse(JSON.load(response.body)["uri"]["query"])["foo"].should == ["bar"]
    end

    it "should send a body" do
      response = client.get(local_server, body: "This is a post body")
      JSON.load(response.body)["body"].should == "This is a post body"
    end
  end

  describe "#post" do
    it "should work" do
      response = client.post(local_server)
      JSON.load(response.body)["method"].should == "POST"
    end

    it "should send a body" do
      response = client.post(local_server, body: "This is a post body")
      JSON.load(response.body)["body"].should == "This is a post body"
    end

    it "should send a UTF-8 body" do
      response = client.post(local_server, body: "This is a post body ∑")
      JSON.load(response.body)["body"].should == "This is a post body ∑"
    end

    it "should send params" do
      response = client.post(local_server, params: {key: "value"})
      CGI.unescape(JSON.load(response.body)["body"]).should == "key=value"
    end

    it "should send non-ASCII params" do
      response = client.post(local_server, params: {"∑" => "√"})
      CGI.unescape(JSON.load(response.body)["body"]).should == "∑=√"
    end

    it "should send an arbitrary entity" do
      f = open(__FILE__, "r").to_inputstream
      multipart_entity = MultipartEntityBuilder.create.add_text_body("foo", "bar").add_binary_body("whatever", f , ContentType::TEXT_PLAIN, __FILE__)
      response = client.post(local_server, entity: multipart_entity.build)
      response.body.should match("should send an arbitrary entity")
    end
  end

  describe "#put" do
    it "should work" do
      response = client.put(local_server)
      JSON.load(response.body)["method"].should == "PUT"
    end

    it "should send a body" do
      response = client.put(local_server, body: "This is a put body")
      JSON.load(response.body)["body"].should == "This is a put body"
    end

    it "should send params" do
      response = client.put(local_server, params: {key: "value"})
      JSON.load(response.body)["body"].should == "key=value"
    end
  end

  describe "#head" do
    it "should work" do
      response = client.head(local_server)
      JSON.load(response.body).should be_nil
    end
  end

  describe "#options" do
    it "should work" do
      response = client.options(local_server)
      JSON.load(response.body)["method"].should == "OPTIONS"
    end
  end

  describe "#patch" do
    it "should work" do
      response = client.patch(local_server)
      JSON.load(response.body)["method"].should == "PATCH"
    end

    it "should send a body" do
      response = client.patch(local_server, body: "This is a patch body")
      JSON.load(response.body)["body"].should == "This is a patch body"
    end

    it "should send params" do
      response = client.patch(local_server, params: {key: "value"})
      JSON.load(response.body)["body"].should == "key=value"
    end
  end

  describe "#execute!" do
    it "should perform multiple concurrent requests" do
      futures = [55441, 55442].map do |port|
        client.async.get("http://localhost:#{port}/?sleep=1").
          on_success do |response|
            Time.now.to_f
          end
      end

      client.execute!
      values = futures.map(&:callback_result)
      (values[0] - values[1]).abs.should < 0.25
    end

    it "should return the results of the handler blocks" do
      [55441, 55442].each do |port|
        client.async.get("http://localhost:#{port}/").
          on_success {|response, request| "Result" }
      end

      client.execute!.map(&:callback_result).should == ["Result", "Result"]
    end
  end

  describe "#clear_pending" do
    it "should remove pending requests" do
      ran = false
      client.async.get("http://google.com").on_success {|r| ran = true }
      client.clear_pending
      client.execute!.should be_empty
      ran.should be false
    end
  end

  describe "#stub" do
    it "should respond with a stubbed response until it is unstubbed" do
      client.stub(local_server, body: "body", code: 200)

      called = false
      2.times {
        client.get(local_server) do |response|
          called = true
          response.should be_a Manticore::StubbedResponse
          response.body.should == "body"
          response.code.should == 200
        end
      }

      called.should be true

      client.clear_stubs!
      client.get(local_server) do |response|
        response.should be_a Manticore::Response
        response.body.should match(/Manticore/)
        response.code.should == 200
      end
    end

    context 'stubbing' do
      it "only the provided URLs" do
        client.stub local_server, body: "body"
        client.async.get(local_server).on_success {|r| r.should be_a Manticore::StubbedResponse }
        client.async.get(local_server("/other")).on_success {|r| r.should_not be_a Manticore::StubbedResponse }
        client.execute!
      end

      it "by regex matching" do
        client.stub %r{#{local_server("/foo")}}, body: "body"
        client.async.get(local_server("/foo")).on_success {|r| r.should be_a Manticore::StubbedResponse }
        client.async.get(local_server("/bar")).on_success {|r| r.should_not be_a Manticore::StubbedResponse }
        client.execute!
      end

      it "strictly matches string stubs" do
        client.stub local_server("/foo"), body: "body"
        client.async.get(local_server("/foo")).on_success {|r| r.should be_a Manticore::StubbedResponse }
        client.async.get(local_server("/other")).on_success {|r| r.should_not be_a Manticore::StubbedResponse }
        client.execute!
      end

      it "matches stubs with query strings" do
        url = "http://google.com?k=v"
        client.stub(url, body: "response body", code: 200)
        client.get(url) do |response|
          expect(response.body).to eq("response body")
        end
      end

      it "persists the stub for non-block calls" do
        url = "http://google.com"
        client.stub(url, body: "response body", code: 200)
        response = client.get(url)
        expect(response.body).to eq("response body")
      end
    end
  end

  describe "keepalive" do
    let(:url) { "http://www.facebook.com/" }

    context "with keepalive" do
      let(:client) { Manticore::Client.new keepalive: true, pool_max: 1 }

      it "should keep the connection open after a request" do
        skip
        response = client.get(url).call
        get_connection(client, url) do |conn|
          conn.is_open.should be true
        end
      end
    end

    context "without keepalive" do
      let(:client) { Manticore::Client.new keepalive: false, pool_max: 1 }

      it "should close the connection after a request" do
        skip
        response = client.get(url).call
        puts `netstat -apn`
        # get_connection(client, url) do |conn|
        #   conn.is_open.should be false
        # end
      end
    end
  end

  context "with a misbehaving endpoint" do
    before do
      @socket = TCPServer.new 4567
      @server = Thread.new do
        puts "Accepting"
        loop do
          client = @socket.accept
          client.puts([
            "HTTP/1.1 200 OK",
            "Keep-Alive: timeout=3000",
            "Connection: Keep-Alive",
            "Content-Length: 6",
            "",
            "Hello!"
          ].join("\n"))
          client.close
        end
      end
    end

    let(:client) { Manticore::Client.new keepalive: true, pool_max: 1 }

    it "should retry 3 times by default" do
      # The first time, reply with keepalive, then close the connection
      # The second connection should succeed

      request1 = client.get("http://localhost:4567/")
      request2 = client.get("http://localhost:4567/")
      expect { request1.call }.to_not raise_exception
      expect { request2.call }.to_not raise_exception

      request1.times_retried.should == 0
      request2.times_retried.should == 1
    end

    context "when the max retry is restrictive" do
      let(:client) { Manticore::Client.new keepalive: true, pool_max: 1, automatic_retries: 0 }

      it "should retry 0 times and fail on the second request" do
        # The first time, reply with keepalive, then close the connection
        # The second connection should succeed
        expect { client.get("http://localhost:4567/").call }.to_not raise_exception
        expect { client.get("http://localhost:4567/").call }.to raise_exception(Manticore::SocketException)
      end
    end

    context "when keepalive is off" do
      let(:client) { Manticore::Client.new keepalive: false, pool_max: 1 }

      it "should succeed without any retries" do
        # The first time, reply with keepalive, then close the connection
        # The second connection should succeed
        request1 = client.get("http://localhost:4567/")
        request2 = client.get("http://localhost:4567/")
        expect { request1.call }.to_not raise_exception
        expect { request2.call }.to_not raise_exception

        request1.times_retried.should == 0
        request2.times_retried.should == 0
      end
    end

    after do
      Thread.kill @server
      @socket.close
    end
  end

  describe "with connection timeouts" do
    let(:client) { Manticore::Client.new request_timeout: 1, connect_timeout: 1, socket_timeout: 1 }

    it "should time out" do
      expect { client.get(local_server "/?sleep=2").body }.to raise_exception(Manticore::Timeout)
    end

    it "should time out when custom request options are passed" do
      expect { client.get(local_server("/?sleep=2"), max_redirects: 5).body }.to raise_exception(Manticore::Timeout)
    end
  end

  def get_connection(client, uri, &block)
    java_import "java.util.concurrent.TimeUnit"
    host = URI.parse(uri).host
    pool = client.instance_variable_get("@pool")
    req = pool.requestConnection(Java::OrgApacheHttpConnRouting::HttpRoute.new( Java::OrgApacheHttp::HttpHost.new(host) ), nil)
    conn = req.get(3, TimeUnit::SECONDS)
    begin
      yield conn
    ensure
      pool.releaseConnection(conn, nil, 0, TimeUnit::SECONDS)
    end
  end
end
