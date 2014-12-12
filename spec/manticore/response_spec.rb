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

  it "should read the status code" do
    subject.code.should eq 200
  end

  it "should read the status text" do
    subject.message.should match "OK"
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

  context "when an entity fails to read" do
    it "releases the connection" do
      stats_before = client.pool_stats
      Manticore::EntityConverter.any_instance.should_receive(:read_entity).and_raise(Manticore::StreamClosedException)
      expect { client.get(local_server).call rescue nil }.to_not change { client.pool_stats[:available] }
    end
  end
end
