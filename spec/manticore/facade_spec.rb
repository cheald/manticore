require 'spec_helper'

describe Manticore::Facade do
  context "when extended into an arbitrary class" do
    let(:extended_class) {
     Class.new do
        include Manticore::Facade
        include_http_client
      end
    }

    let(:extended_shared_class) {
     Class.new do
        include Manticore::Facade
        include_http_client shared_pool: true
      end
    }

    it "should get a response" do
      result = JSON.parse extended_class.get(local_server).body
      result["method"].should == "GET"
    end

    it "should not use the shared client by default" do
      extended_class.instance_variable_get("@manticore_facade").object_id.should_not ==
        Manticore.instance_variable_get("@manticore_facade").object_id
    end

    it "should be able to use the shared client" do
      extended_shared_class.instance_variable_get("@manticore_facade").object_id.should ==
        Manticore.instance_variable_get("@manticore_facade").object_id
    end
  end

  context "from the default Manticore module" do
    it "should get a response" do
      result = JSON.parse Manticore.get(local_server).body
      result["method"].should == "GET"
    end
  end
end