module BSONCr
  class ObejctIdBuilder
    MAX_COUNTER    =     0xFFFFFF_u32
    MAX_MACHINE_ID = 0xFFFFFFFFFF_u64
    getter counter : UInt32 = Random.rand(MAX_COUNTER + 1)
    getter machine_id : UInt64 = Random.rand(MAX_MACHINE_ID + 1)

    def counter_slice
      pointerof(@counter)
        .as(Pointer(UInt8))
        .to_slice(3)
    end

    def machine_id_slice
      pointerof(@machine_id)
        .as(Pointer(UInt8))
        .to_slice(5)
    end

    def build
      time = Time.utc.to_unix.to_u32

      time_ptr = pointerof(time).as(Pointer(UInt8)).to_slice(4)
      counter = @counter
      @counter = (@counter + 1) % (MAX_COUNTER + 1)

      bytes = uninitialized UInt8[ObjectId::BYTES_SIZE]
      # Copy time bytes in big-endian order (most significant byte first)
      4.times do |i|
        bytes[0 + i] = time_ptr[3 - i]
      end

      5.times do |i|
        bytes[4 + i] = machine_id_slice[i]
      end

      3.times do |i|
        bytes[9 + i] = counter_slice[2 - i]
      end

      ObjectId.new(bytes)
    end
  end

  struct ObjectId
    BYTES_SIZE = 12
    getter bytes : StaticArray(UInt8, BYTES_SIZE)

    def initialize(@bytes)
    end

    def inspect(io : IO)
      io << "#<BSONCr::ObjectId "
      to_s(io)
      io << " >"
    end

    def self.create
      builder = ObejctIdBuilder.new
      builder.build
    end

    def to_s
      @bytes.to_slice.hexstring
    end

    def to_s(io : IO)
      io << to_s
    end

    def to_datetime
      timestamp = @bytes.to_slice[0...4].clone.reverse!.to_unsafe.as(Pointer(UInt32)).value

      Time.unix(timestamp)
    end

    def self.parse(str : String)
      bytes = uninitialized UInt8[BYTES_SIZE]
      unsafe_str = str.to_unsafe
      i = 0
      while i < 24
        high_nibble = unsafe_str[i].unsafe_chr.to_u8?(16).not_nil!
        low_nibble = unsafe_str[i + 1].unsafe_chr.to_u8?(16).not_nil!

        bytes[i // 2] = (high_nibble << 4) | low_nibble

        i += 2
      end

      new(bytes)
    end
  end
end
