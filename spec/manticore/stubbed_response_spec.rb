require 'spec_helper'

describe Manticore::StubbedResponse do
  subject {
    Manticore::StubbedResponse.stub(
      body: "test body",
      code: 200,
      headers: {
        "Content-Type" => "text/plain",
        "Set-Cookie" => ["k=v; path=/; domain=localhost", "k=v; path=/sub; domain=sub.localhost", "k2=v2;2 path=/; domain=localhost"]
      },
      cookies: {"test" => Manticore::Cookie.new(name: "test", value: "something", path: "/")}
    ).call
  }

  it { should be_a Manticore::Response }
  its(:body) { should == "test body" }
  its(:code) { should == 200 }

  it "should persist the set headers" do
    subject.headers["content-type"].should == "text/plain"
  end

  it "should set content-length from the body" do
    subject.headers["content-length"].should == 9
  end

  it "should persist cookies passed as explicit cookie objects" do
    subject.cookies["test"].first.value.should == "something"
  end

  it "should call on_success handlers" do
    called = false
    Manticore::StubbedResponse.stub.on_success {|resp| called = true }.call
    called.should be true
  end

  it "should persist cookies passed in set-cookie" do
    subject.cookies["k"].map(&:value).should  =~ ["v", "v"]
    subject.cookies["k"].map(&:path).should   =~ ["/", "/sub"]
    subject.cookies["k"].map(&:domain).should =~ ["localhost", "sub.localhost"]
    subject.cookies["k2"].first.value.should == "v2"
  end
end
