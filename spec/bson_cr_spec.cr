require "./spec_helper"
require "json"

describe BSONCr do
  # TODO: Write tests

  it "works" do
    BSONCr.encode({"name" => "John", "age" => 30, "city" => "New York"})
    BSONCr.decode
  end

  it "acts like json" do
    record = {"name" => "John", "age" => 30, "city" => "New York"}

    JSON.parse(record.to_json) # should eq(record)
    # bytes = Bytes.new
  end

  describe BSONCr::ObjectId do
    it "creates a new ObjectId" do
      builder = BSONCr::ObejctIdBuilder.new
      object_id = builder.build

      object_id2 = builder.build

      object_id.should_not eq(object_id2)
    end

    it "creates ObjectId from string" do
      builder = BSONCr::ObejctIdBuilder.new
      object_id = builder.build

      object_id_from_str = BSONCr::ObjectId.parse(object_id.to_s)

      object_id.should eq(object_id_from_str)
    end
  end
end
