require 'spec_helper'

describe Manticore::Client do
  let(:client) { Manticore::Client.new }

  it "should fetch a URL and return a response" do
    client.get(local_server).should be_a Manticore::Response
  end

  it "should resolve redirections" do
    response = client.get(local_server, {"X-Redirect" => "/foobar"})
    response.code.should == 200
    response.final_url.should == URI(local_server("/foobar"))
  end

  it "should accept custom headers" do
    response = client.get(local_server, {"X-Custom-Header" => "Blaznotts"})
    json = JSON.load(response.body)
    json["headers"]["X-Custom-Header"].should == "Blaznotts"
  end

  it "should enable compression" do
    response = client.get(local_server)
    json = JSON.load(response.body)
    json["headers"].should have_key "Accept-Encoding"
    json["headers"]["Accept-Encoding"].should match("gzip")
  end

  context "when compression is disabled" do
    let(:client) {
      Manticore::Client.new do |client|
        client.disable_content_compression
      end
    }

    it "should disable compression" do
      response = client.get(local_server)
      json = JSON.load(response.body)
      json["headers"]["Accept-Encoding"].should be_nil
    end
  end
end