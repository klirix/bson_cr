require "uuid"
require "./object_id"

module BSONCr
  VERSION = "0.1.0"

  enum TypeByte : UInt8
    Double              = 0x01
    String              = 0x02
    Document            = 0x03
    Array               = 0x04
    Binary              = 0x05
    Undefined           = 0x06 # Deprecated
    ObjectId            = 0x07
    Boolean             = 0x08
    DateTime            = 0x09
    NullValue           = 0x0A
    Regex               = 0x0B
    DBPointer           = 0x0C
    JavaScript          = 0x0D
    Symbol              = 0x0E # Deprecated
    JavaScriptWithScope = 0x0F # Deprecated
    Int32               = 0x10
    Timestamp           = 0x11
    Int64               = 0x12
    Decimal128          = 0x13
    MinKey              = 0xFF
    MaxKey              = 0x7F
  end

  struct Builder
    is_within_container : Bool = false
    bytes : Bytes

    def initialize(@io : IO)
    end
  end

  class Encoder
    getter io : IO

    def initialize(@io : IO)
    end

    def encode(value : Hash(String, Any::Type), offset : UInt32 = 0)
      io.write_bytes(0_i32, IO::ByteFormat::LittleEndian) # Placeholder for document size
      value.each do |k, v|
        write_value(k, v)
      end
      io.write_byte(0) # null terminator for document
      # Now go back and write the document size
      doc_size = (io.pos - offset).to_i32
      current_pos = io.pos
      io.pos = offset
      io.write_bytes(doc_size, IO::ByteFormat::LittleEndian)
      io.pos = current_pos
    end

    def encode(value : Array(Any::Type), offset : UInt32 = 0)
      io.write_bytes(0_i32, IO::ByteFormat::LittleEndian) # Placeholder for document size
      value.each_with_index do |v, i|
        write_value(i.to_s, v)
      end
      io.write_byte(0) # null terminator for document
      # Now go back and write the document size
      doc_size = (io.pos - offset).to_i32
      current_pos = io.pos
      io.pos = offset
      io.write_bytes(doc_size, IO::ByteFormat::LittleEndian)
      io.pos = current_pos
    end

    def write_value(k : String, v : Array(Any::Type))
      io.write_byte(TypeByte::Array.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      encode(v, io.pos.to_u!)
    end

    def write_value(k : String, v : Bytes)
      io.write_byte(TypeByte::Binary.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write_bytes(v.bytesize.to_i32, IO::ByteFormat::LittleEndian)
      io.write_byte(0_u8) # subtype 0: Generic binary subtype
      io.write(v.to_slice)
    end

    def write_value(k : String, v : UUID)
      io.write_byte(TypeByte::Binary.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write_bytes(16, IO::ByteFormat::LittleEndian)
      io.write_byte(4_u8)        # subtype 0: Generic binary subtype
      io.write(v.bytes.to_slice) # UUID is 16 bytes
    end

    def write_value(k : String, v : Bool)
      io.write_byte(TypeByte::Boolean.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write_byte(v ? 1_u8 : 0_u8)
    end

    def write_value(k : String, v : ObjectId)
      io.write_byte(TypeByte::ObjectId.value)
      io.write_string(k.to_slice)
      io.write_byte(0)           # null terminator for key
      io.write(v.bytes.to_slice) # Assuming v is of type ObjectId
    end

    def write_value(k : String, v : Time)
      io.write_byte(TypeByte::DateTime.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      epoch_millis = (v.to_unix * 1000).to_i64
      io.write_bytes(epoch_millis, IO::ByteFormat::LittleEndian)
    end

    def write_value(k : String, value : Nil)
      io.write_byte(TypeByte::NullValue.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
    end

    def write_value(k : String, value : Int64)
      io.write_byte(TypeByte::Int64.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write_bytes(value, IO::ByteFormat::LittleEndian)
    end

    def write_value(k : String, value : Hash(String, Any::Type))
      io.write_byte(TypeByte::Document.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      encode(value, io.pos.to_u!)
    end

    def write_value(k : String, value : Document)
      io.write_byte(TypeByte::Document.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write(value.bytes.to_slice)
    end

    def write_value(k : String, value : DocumentArray)
      io.write_byte(TypeByte::Array.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write(value.bytes.to_slice)
    end

    def write_value(k : String, value : Int32)
      io.write_byte(TypeByte::Int32.value)
      io.write_string(k.to_slice)
      io.write_byte(0) # null terminator for key
      io.write_bytes(value, IO::ByteFormat::LittleEndian)
    end

    def write_value(k : String, value : Float64)
      io.write_byte(TypeByte::Double.value)
      io.write_string(k.to_slice)
      io.write_byte(0)
      io.write_bytes(value, IO::ByteFormat::LittleEndian)
    end

    def write_value(k : String, v : String)
      io.write_byte(TypeByte::String.value)
      io.write_string(k.to_slice)
      io.write_byte(0)                                                      # null terminator for key
      io.write_bytes((v.bytesize + 1).to_i32, IO::ByteFormat::LittleEndian) # include null terminator
      io.write_string(v.to_slice)
      io.write_byte(0)
    end
  end

  struct Any
    alias Scalar = Float64 | String | Bool | Bytes | ObjectId | Time | Nil | Int32 | Int64 | UUID
    alias Value = ADocument | Scalar
    alias Type = Hash(String, Any::Type) | Array(Any::Type) | Scalar
    alias DocType = Hash(String, Any::Type)
  end

  abstract struct ADocument
    property bytes : Bytes

    def initialize(@bytes)
    end

    def empty?
      bytes.size == 5 # 4 bytes for size + 1 byte for null terminator
    end

    def initialize
      @bytes = Bytes.new(5) # 4 bytes for size + 1 byte for null terminator
      @bytes.to_unsafe.as(Pointer(Int32)).value = 5
    end

    def read_value(io, type_byte)
      case type_byte
      when TypeByte::Double.value
        v = io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
        return v
      when TypeByte::String.value
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        v = io.gets('\0', v_size, true).not_nil!
        return v
      when TypeByte::Document.value
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        io.pos -= 4 # rewind to include size in the slice
        v = Bytes.new(v_size)
        io.read(v)
        return Document.new(v)
      when TypeByte::Array.value
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        io.pos -= 4 # rewind to include size in the slice
        v = Bytes.new(v_size)
        io.read(v)
        return DocumentArray.new(v)
      when TypeByte::Binary.value
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        subtype = io.read_byte
        value = Bytes.new(v_size)
        io.read(value)
        case subtype
        when 4_u8, 3_u8 # UUID
          return UUID.new(value.to_slice)
        else
          return value
        end
      when TypeByte::ObjectId.value
        value_bytes = uninitialized UInt8[ObjectId::BYTES_SIZE]
        io.read(value_bytes.to_slice)
        return ObjectId.new(value_bytes)
      when TypeByte::Boolean.value
        v = io.read_byte != 0
        return v
      when TypeByte::DateTime.value
        epoch_millis = io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
        return Time.unix(epoch_millis // 1000)
      when TypeByte::NullValue.value
        return nil
      when TypeByte::Int32.value
        value = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        return value
      when TypeByte::Int64.value
        value = io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
        return value
      else
        raise "Unsupported type byte: #{type_byte}"
      end
    end

    def skip_value(io, type_byte)
      case TypeByte.new(type_byte)
      when TypeByte::Double, TypeByte::Timestamp, TypeByte::Int64, TypeByte::DateTime
        io.pos += 8
      when TypeByte::String
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        io.pos += v_size
      when TypeByte::Document, TypeByte::Array
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        io.pos += (v_size - 4) # already read size
      when TypeByte::Binary
        v_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
        io.pos += (v_size + 1) # +1 for subtype byte
      when TypeByte::ObjectId
        io.pos += ObjectId::BYTES_SIZE
      when TypeByte::Boolean
        io.pos += 1
      when TypeByte::NullValue
        # nothing to skip
      when TypeByte::Int32
        io.pos += 4
      else
        raise "Unsupported type byte: #{type_byte}"
      end
    end

    def inspect(io : IO)
      io << self.class.name
      io << "["
      bytes.each_with_index do |b, i|
        io << ", " if i > 0
        io << b.to_s(16).rjust(2, '0')
      end
      io << "]\n"
    end

    def [](key : String) : Any::Value?
      each_pair do |k, v|
        return v if k == key
      end
    end

    def []=(key : String, value : Any::Value)
      io = IO::Memory.new
      encoder = Encoder.new(io)
      io.write_bytes(0_i32, IO::ByteFormat::LittleEndian) # Placeholder for document size
      found_value : Any::Value? = nil
      each_pair do |k, v|
        encoder.write_value(k, v) if k != key
      end
      encoder.write_value(key, value)
      io.write_byte(0) # null terminator for document
      len = io.pos - 1
      io.pos = 0
      io.write_bytes(len.to_i32, IO::ByteFormat::LittleEndian)
      @bytes = io.to_slice
    end

    def delete(key : String) : Any::Value?
      delete(key) { nil }
    end

    def delete(key : Int) : Any::Value?
      delete(key) { nil }
    end

    def delete(key : String, &)
      io = IO::Memory.new
      encoder = Encoder.new(io)
      io.write_bytes(0_i32, IO::ByteFormat::LittleEndian) # Placeholder for document size
      found_value : Any::Value? = nil
      each_pair do |k, v|
        if k != key
          encoder.write_value(k, v)
        else
          found_value = v
        end
      end
      io.write_byte(0) # null terminator for document
      len = io.pos - 1
      io.pos = 0
      io.write_bytes(len.to_i32, IO::ByteFormat::LittleEndian)
      @bytes = io.to_slice

      found_value
    end

    def each_pair(& : {String, Any::Value} ->)
      io = IO::Memory.new(bytes)
      size = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
      loop do
        type_byte = io.read_byte
        return if type_byte == 0

        key = io.gets('\0', true).not_nil!

        yield ({key, read_value(io, type_byte)})
      end
    end

    def byte_size
      bytes.size
    end

    def count
      n = 0
      io = IO::Memory.new(bytes)

      io.pos += 4 # skip size
      loop do
        type_byte = io.read_byte
        break if type_byte == 0

        while io.read_byte != 0; end # skip key

        skip_value(io, type_byte)
        n += 1
      end
      n
    end
  end

  struct Document < ADocument
    include Enumerable({String, Any::Value})

    def to_h
      hash = Hash(String, Any::Type).new
      each_pair do |k, v|
        case v
        when Document
          hash[k] = v.to_h
        when DocumentArray
          hash[k] = v.to_a
        when ADocument
          raise "Unknown ADocument subclass: #{v.class}"
        else
          hash[k] = v
        end
      end
      hash
    end

    def each(&)
      each_pair do |k, v|
        yield ({k, v})
      end
    end
  end

  struct DocumentArray < ADocument
    include Enumerable(Any::Type)

    def to_a
      arr = Array(Any::Type).new
      each_pair do |_, v|
        case v
        when Document
          arr << v.to_h
        when DocumentArray
          arr << v.to_a
        when ADocument
          raise "Unknown ADocument subclass: #{v.class}"
        else
          arr << v
        end
      end
      arr
    end

    def each(&)
      each_pair do |_, v|
        yield v
      end
    end
  end

  # class Decoder
  #   io : IO
  #   offset : Int32 = 0

  #   def next_token
  #   end
  # end

  # TODO: Put your code here
  def self.encode(record : Any::DocType) : Document
    io = IO::Memory.new
    Encoder.new(io).encode(record)
    Document.new(io.to_slice)
  end

  def self.encode(record : NamedTuple)
    hash = Hash(String, Any::Type).new(record.size)
    record.each do |k, v|
      hash[k.to_s] = v
    end
    encode(hash)
  end

  def self.decode
  end
end
