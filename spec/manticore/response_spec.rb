require 'spec_helper'

describe Manticore::Response do
  let(:client) { Manticore::Client.new }
  subject { client.get( local_server ) }

  its(:headers) { should be_a Hash }
  its(:body)    { should be_a String }
  its(:length)  { should be_a Fixnum }

  it "should read the body" do
    subject.body.should match "Manticore"
  end

  context "when the client is invoked with a block" do
    it "should allow reading the body from a block" do
      response = client.get(local_server) do |response|
        response.body.should match 'Manticore'
      end

      response.body.should match "Manticore"
    end

    it "should not read the body implicitly if called with a block" do
      response = client.get(local_server) {}
      expect { response.body }.to raise_exception(Manticore::StreamClosedException)
    end
  end
end