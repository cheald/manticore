require 'spec_helper'
describe Manticore::Client do
  let(:client) { Manticore::Client.new }

  describe Manticore::Client::StubProxy do
    describe "#respond_with" do
      it "should respond with a stubbed response" do
        client.respond_with(body: "body", code: 200).get(local_server).on_success do |response|
          response.should be_a Manticore::StubbedResponse
          response.body.should == "body"
          response.code.should == 200
        end
      end

      context "for synchronous requests" do
        it "should respond only stub the next subsequent response" do
          stub = client.respond_with(body: "body", code: 200)

          stub.get(local_server) do |response|
            response.should be_a Manticore::StubbedResponse
          end

          stub.get(local_server) do |response|
            response.should be_a Manticore::Response
          end
        end
      end

      context "for synchronous requests" do
        it "should respond only stub the next subsequent response" do
          stub = client.respond_with(body: "body", code: 200)

          stub.async.get(local_server).on_success do |response|
            response.should be_a Manticore::StubbedResponse
          end

          stub.async.get(local_server).on_success do |response|
            response.should be_a Manticore::Response
          end

          client.execute!
        end
      end
    end
  end

  describe Manticore::Client::AsyncProxy do
    it "should not make a request until execute is called" do
      anchor = Time.now.to_f
      client.async.get("http://localhost:55441/?sleep=1.6")
      (Time.now.to_f - anchor).should < 1.0

      anchor = Time.now.to_f
      client.execute!
      (Time.now.to_f - anchor).should > 1.0
    end

    it "should return the response object, which may then have handlers attached" do
      response = client.async.get("http://localhost:55441/")
      success = false
      response.on_success do
        success = true
      end

      client.execute!
      success.should == true
    end

    it "can chain handlers" do
      client.async.get("http://localhost:55441/").on_success {|r| r.code }
      client.execute!.map(&:callback_result).should == [200]
    end
  end

  describe Manticore::Client::BackgroundProxy do
    it "should not block execution" do
      anchor = Time.now.to_f
      future = client.background.get("http://localhost:55441/?sleep=1.5")
      (Time.now.to_f - anchor).should < 1.0

      response = future.get
      (Time.now.to_f - anchor).should > 1.0
      response.body.should match(/sleep=1.5/)
    end

    it "should return a future" do
      response = client.background.get("http://localhost:55441/")
      response.should be_a Java::JavaUtilConcurrent::FutureTask
      response.get
    end
  end
end