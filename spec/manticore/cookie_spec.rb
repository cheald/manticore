require 'spec_helper'

describe Manticore::Cookie do
  context "created from a Client request" do
    let(:client) { Manticore::Client.new cookies: true }
    subject {
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].first
    }

    its(:name)   { should be_a String }
    its(:value)  { should be_a String }
    its(:path)   { should be_a String }
    its(:domain) { should be_a String }
  end
end