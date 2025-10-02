require "./spec_helper"
require "json"

describe BSONCr do
  it "works" do
    base = {
      "name" => "John",
      "age" => 30, "array" => [1, 2, 3],
      "nested" => {"key" => "value"},
      "uuid" => UUID.v7,
      "object_id" => BSONCr::ObjectId.create,
    }
    doc = BSONCr.encode(base)

    doc.size.should eq base.size

    pp doc.to_h
    doc.to_h.should eq(base)
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
