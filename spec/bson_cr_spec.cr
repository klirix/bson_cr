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

  it "encodes size correctly" do
    base = {"query" => {} of String => String}
    doc = BSONCr.encode(base)

    doc.bytes.size.should eq 17

    doc.bytes.to_unsafe.unsafe_as(Pointer(Int32)).value.should eq 17

    doc2 = BSONCr::Document{"query" => BSONCr::Document.new}

    doc2.bytes.size.should eq 17
    doc2.bytes.to_unsafe.unsafe_as(Pointer(Int32)).value.should eq 17
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

    it "encodes ObjectId properly in document" do
      builder = BSONCr::ObejctIdBuilder.new
      object_id = builder.build

      doc = BSONCr::Document{"_id" => object_id, "name" => "John"}

      encoded_doc = BSONCr.encode(doc.to_h)

      decoded_doc = BSONCr::Document.new(encoded_doc.bytes)

      decoded_doc["_id"].should eq(object_id)
      decoded_doc["name"].should eq("John")
    end

    it "encodes and decodes ObjectId to/from hex string" do
      object_id = BSONCr::ObjectId.create
      hex_string = object_id.to_s

      # Hex string should be 24 characters (12 bytes * 2)
      hex_string.size.should eq 24

      # Parse it back
      parsed_id = BSONCr::ObjectId.parse(hex_string)

      # Should be identical
      parsed_id.should eq(object_id)
      parsed_id.to_s.should eq(hex_string)
    end

    it "round-trips multiple ObjectIds in a document" do
      object_id1 = BSONCr::ObjectId.create
      object_id2 = BSONCr::ObjectId.create
      object_id3 = BSONCr::ObjectId.create

      original_doc = {
        "id1" => object_id1,
        "id2" => object_id2,
        "id3" => object_id3,
      }

      encoded = BSONCr.encode(original_doc)
      decoded = BSONCr::Document.new(encoded.bytes)

      decoded["id1"].should eq(object_id1)
      decoded["id2"].should eq(object_id2)
      decoded["id3"].should eq(object_id3)
    end

    it "preserves ObjectId bytes through encoding/decoding" do
      object_id = BSONCr::ObjectId.create

      # Convert to hash and encode
      doc_hash = {"_id" => object_id}
      encoded = BSONCr.encode(doc_hash)

      # Decode back
      decoded = BSONCr::Document.new(encoded.bytes)
      decoded_id = decoded["_id"]

      # Verify bytes are identical
      (decoded_id.as(BSONCr::ObjectId)).bytes.should eq(object_id.bytes)
    end

    it "handles ObjectId in nested documents" do
      object_id = BSONCr::ObjectId.create

      original_doc = {
        "user" => {
          "_id" => object_id,
          "name" => "Alice",
        }
      }

      encoded = BSONCr.encode(original_doc)
      decoded = BSONCr::Document.new(encoded.bytes)

      nested_user = decoded["user"].as(BSONCr::Document)
      nested_user["_id"].should eq(object_id)
      nested_user["name"].should eq("Alice")
    end

    it "hex string parsing handles different cases" do
      object_id = BSONCr::ObjectId.create
      hex_lower = object_id.to_s.downcase
      hex_upper = object_id.to_s.upcase

      parsed_lower = BSONCr::ObjectId.parse(hex_lower)
      parsed_upper = BSONCr::ObjectId.parse(hex_upper)

      parsed_lower.should eq(object_id)
      parsed_upper.should eq(object_id)
      parsed_lower.should eq(parsed_upper)
    end

    it "ObjectId extracted timestamp is reasonable" do
      before_creation = Time.utc.to_unix
      object_id = BSONCr::ObjectId.create
      after_creation = Time.utc.to_unix

      timestamp = object_id.to_datetime.to_unix

      # Timestamp should be within creation time window
      timestamp.should be >= before_creation
      timestamp.should be <= after_creation
    end

    it "different ObjectIds have different byte representations" do
      object_id1 = BSONCr::ObjectId.create
      object_id2 = BSONCr::ObjectId.create

      # They should have different hex strings and bytes
      object_id1.to_s.should_not eq(object_id2.to_s)
      object_id1.bytes.should_not eq(object_id2.bytes)
    end

    describe "with fixtures" do
      # Fixture: User document with ObjectId
      fixture_user_with_id = {
        "_id" => BSONCr::ObjectId.create,
        "username" => "alice",
        "email" => "alice@example.com",
        "age" => 28,
      }

      # Fixture: Product document with ObjectId
      fixture_product_with_id = {
        "_id" => BSONCr::ObjectId.create,
        "name" => "Laptop",
        "price" => 999.99,
        "in_stock" => true,
      }

      # Fixture: Order with multiple ObjectIds
      fixture_order_with_ids = {
        "_id" => BSONCr::ObjectId.create,
        "user_id" => BSONCr::ObjectId.create,
        "product_ids" => [
          BSONCr::ObjectId.create,
          BSONCr::ObjectId.create,
        ],
        "total" => 1999.98,
      }

      it "encodes and decodes user fixture with ObjectId" do
        user_id = fixture_user_with_id["_id"]
        encoded = BSONCr.encode(fixture_user_with_id)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded["_id"].should eq(user_id)
        decoded["username"].should eq("alice")
        decoded["email"].should eq("alice@example.com")
        decoded["age"].should eq(28)
      end

      it "encodes and decodes product fixture with ObjectId" do
        product_id = fixture_product_with_id["_id"]
        encoded = BSONCr.encode(fixture_product_with_id)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded["_id"].should eq(product_id)
        decoded["name"].should eq("Laptop")
        decoded["price"].should eq(999.99)
        decoded["in_stock"].should eq(true)
      end

      it "encodes and decodes order fixture with multiple ObjectIds" do
        order_id = fixture_order_with_ids["_id"]
        user_id = fixture_order_with_ids["user_id"]

        encoded = BSONCr.encode(fixture_order_with_ids)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded["_id"].should eq(order_id)
        decoded["user_id"].should eq(user_id)
        decoded["total"].should eq(1999.98)

        # Verify product IDs array decoding
        decoded_products = decoded["product_ids"].as(BSONCr::DocumentArray)
        decoded_products.to_a.size.should eq(2)
      end

      it "preserves ObjectId fixture data through multiple encode/decode cycles" do
        user_id = fixture_user_with_id["_id"]
        
        # First encode/decode cycle
        encoded1 = BSONCr.encode(fixture_user_with_id)
        decoded1 = BSONCr::Document.new(encoded1.bytes)
        
        # Second encode/decode cycle - re-encode the same fixture
        encoded2 = BSONCr.encode(fixture_user_with_id)
        decoded2 = BSONCr::Document.new(encoded2.bytes)

        # All cycles should preserve the original ObjectId
        decoded1["_id"].should eq(user_id)
        decoded2["_id"].should eq(user_id)
      end

      it "correctly handles fixture with nested documents containing ObjectIds" do
        fixture_nested = {
          "_id" => BSONCr::ObjectId.create,
          "title" => "Project Alpha",
          "owner" => {
            "_id" => BSONCr::ObjectId.create,
            "name" => "Bob",
          },
          "collaborators" => {
            "_id" => BSONCr::ObjectId.create,
            "name" => "Charlie",
          },
        }

        encoded = BSONCr.encode(fixture_nested)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded["_id"].should be_a(BSONCr::ObjectId)
        
        nested_owner = decoded["owner"].as(BSONCr::Document)
        nested_owner["_id"].should be_a(BSONCr::ObjectId)
        nested_owner["name"].should eq("Bob")
      end

      it "fixture ObjectIds maintain string representation consistency" do
        fixture_simple = {
          "_id" => BSONCr::ObjectId.create,
          "data" => "test",
        }

        original_id_str = fixture_simple["_id"].to_s
        encoded = BSONCr.encode(fixture_simple)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded_id_str = decoded["_id"].as(BSONCr::ObjectId).to_s
        decoded_id_str.should eq(original_id_str)
      end

      it "fixture with mixed data types including ObjectId" do
        fixture_mixed = {
          "_id" => BSONCr::ObjectId.create,
          "string_field" => "Hello",
          "int_field" => 42,
          "float_field" => 3.14,
          "bool_field" => true,
          "nil_field" => nil,
          "time_field" => Time.utc(2025, 10, 31, 12, 0, 0),
        }

        encoded = BSONCr.encode(fixture_mixed)
        decoded = BSONCr::Document.new(encoded.bytes)

        decoded["_id"].should be_a(BSONCr::ObjectId)
        decoded["string_field"].should eq("Hello")
        decoded["int_field"].should eq(42)
        decoded["float_field"].should eq(3.14)
        decoded["bool_field"].should eq(true)
        decoded["nil_field"].should be_nil
        decoded["time_field"].should be_a(Time)
      end
    end
  end
end
