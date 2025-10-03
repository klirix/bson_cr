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

  describe "#delete" do
    it "deletes key and returns value" do
      doc = BSONCr.encode({"name" => "John", "age" => 30, "city" => "New York"})

      doc.delete("age").should eq 30
      doc.size.should eq 2

      # bytes = Bytes.new
    end

    it "deletes non-existing key and returns nil" do
      doc = BSONCr.encode({"name" => "John", "age" => 30, "city" => "New York"})

      doc.delete("country").should be_nil
      doc.size.should eq 3
    end
  end

  describe "#[]=, #[]" do
    it "sets and gets value by key" do
      doc = BSONCr.encode({"name" => "John", "age" => 30})

      doc["city"] = "New York"
      doc.size.should eq 3
      doc["city"].should eq "New York"

      doc["age"] = 31
      doc.size.should eq 3
      doc["age"].should eq 31
    end
  end

  describe "#empty?" do
    it "returns true for empty document" do
      doc = BSONCr::Document.new

      doc.empty?.should be_true
    end

    it "returns false for non-empty document" do
      doc = BSONCr::Document{"name" => "John"}

      doc.empty?.should be_false
    end
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
