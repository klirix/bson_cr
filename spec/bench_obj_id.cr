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
