require "benchmark"
require "../src/bson_cr.cr"
require "bson"

builder = BSONCr::ObejctIdBuilder.new

Benchmark.ips do |x|
  x.report("bson.cr ObjectId") {
    BSON::ObjectId.new
  }
  x.report("my ObjectId") {
    builder.build
  }
end

Benchmark.ips do |x|
  object_id = BSON::ObjectId.new
  object_id_str = object_id.to_s

  x.report("bson.cr ObjectId from string") {
    BSON::ObjectId.new(object_id_str)
  }
  x.report("my ObjectId from string") {
    BSONCr::ObjectId.parse(object_id_str)
  }
end

Benchmark.ips do |x|
  base = {"name" => "John", "age" => 30, "array" => [1, 2, 3], "nested" => {"key" => "value"}}

  x.report("bson.cr encode") {
    BSON.new(base)
  }
  x.report("my encode") {
    BSONCr.encode(base)
  }
end

Benchmark.ips do |x|
  base = {"name" => "John", "age" => 30, "array" => [1, 2, 3], "nested" => {"key" => "value"}}
  encoded_bytes = BSONCr.encode(base)

  x.report("bson.cr decode") {
    BSON.new(encoded_bytes.bytes).to_h
  }
  x.report("my decode") {
    BSONCr::Document.new(encoded_bytes.bytes).to_h
  }
end
