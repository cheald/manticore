require 'spec_helper'

describe Manticore::Cookie do
  context "created from a Client request" do
    let(:client) { Manticore::Client.new cookies: true }
    subject {
      response = client.get(local_server("/cookies/1/2"))
      response.final_url.to_s.should == local_server("/cookies/2/2")
      response.cookies["x"].first
    }

    its(:name)   { should == "x" }
    its(:value)  { should == "2" }
    its(:path)   { should == "/" }
    its(:domain) { should == "localhost" }
  end


  let(:opts) {{}}
  subject {
    Manticore::Cookie.new({name: "foo", value: "bar"}.merge(opts))
  }

  its(:secure?)     { should be nil }
  its(:persistent?) { should be nil }

  context "created as secure" do
    let(:opts) {{ secure: true }}
    its(:secure?) { should be true }
  end

  context "created as persistent" do
    let(:opts) {{ persistent: true }}
    its(:persistent?) { should be true }
  end
end