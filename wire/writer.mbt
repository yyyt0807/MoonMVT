///|
/// Append-only protobuf writer used by the deterministic MVT encoder.
pub(all) struct Writer {
  output : Array[Byte]
}

///|
pub fn Writer::new() -> Writer {
  { output: [], }
}

///|
pub fn Writer::length(self : Writer) -> Int32 {
  self.output.length()
}

///|
pub fn Writer::is_empty(self : Writer) -> Bool {
  self.output.is_empty()
}

///|
pub fn Writer::finish(self : Writer) -> Bytes {
  Bytes::from_array(self.output.copy())
}

///|
pub fn Writer::write_key(
  self : Writer,
  number : Int32,
  wire_type : WireType,
) -> Unit raise @error.MvtError {
  append_varint(self.output, encode_field_key(number, wire_type))
}

///|
pub fn Writer::write_raw_varint(self : Writer, value : UInt64) -> Unit {
  append_varint(self.output, value)
}

///|
pub fn Writer::write_varint_field(
  self : Writer,
  number : Int32,
  value : UInt64,
) -> Unit raise @error.MvtError {
  self.write_key(number, WireType::Varint)
  self.write_raw_varint(value)
}

///|
pub fn Writer::write_sint64_field(
  self : Writer,
  number : Int32,
  value : Int64,
) -> Unit raise @error.MvtError {
  self.write_varint_field(number, zigzag_encode_i64(value))
}

///|
pub fn Writer::write_fixed32_field(
  self : Writer,
  number : Int32,
  value : UInt32,
) -> Unit raise @error.MvtError {
  self.write_key(number, WireType::Fixed32)
  self.write_raw_fixed32(value)
}

///|
pub fn Writer::write_fixed64_field(
  self : Writer,
  number : Int32,
  value : UInt64,
) -> Unit raise @error.MvtError {
  self.write_key(number, WireType::Fixed64)
  self.write_raw_fixed64(value)
}

///|
pub fn Writer::write_raw_fixed32(self : Writer, value : UInt32) -> Unit {
  for shift in [0, 8, 16, 24] {
    self.output.push(((value >> shift) & 0xffU).reinterpret_as_int().to_byte())
  }
}

///|
pub fn Writer::write_raw_fixed64(self : Writer, value : UInt64) -> Unit {
  for shift in [0, 8, 16, 24, 32, 40, 48, 56] {
    self.output.push(((value >> shift) & 0xffUL).to_int().to_byte())
  }
}

///|
pub fn Writer::write_bytes_field(
  self : Writer,
  number : Int32,
  value : Bytes,
) -> Unit raise @error.MvtError {
  self.write_key(number, WireType::LengthDelimited)
  append_varint(self.output, value.length().to_uint64())
  append_bytes(self.output, value)
}

///|
pub fn Writer::write_string_field(
  self : Writer,
  number : Int32,
  value : String,
) -> Unit raise @error.MvtError {
  self.write_bytes_field(number, @utf8.encode(value))
}

///|
pub fn Writer::write_message_field(
  self : Writer,
  number : Int32,
  message : Writer,
) -> Unit raise @error.MvtError {
  self.write_bytes_field(number, message.finish())
}

///|
pub fn Writer::write_packed_uint32(
  self : Writer,
  number : Int32,
  values : ArrayView[Int32],
) -> Unit raise @error.MvtError {
  if values.is_empty() {
    return
  }
  let packed = Writer::new()
  for value in values {
    if value < 0 {
      raise @error.MvtError::InvalidArgument(
        "packed uint32 values must not be negative",
      )
    }
    packed.write_raw_varint(value.to_uint64())
  }
  self.write_message_field(number, packed)
}

///|
/// Write packed uint32 words including values above signed Int maximum.
pub fn Writer::write_packed_words(
  self : Writer,
  number : Int32,
  values : ArrayView[UInt32],
) -> Unit raise @error.MvtError {
  if values.is_empty() {
    return
  }
  let packed = Writer::new()
  for value in values {
    packed.write_raw_varint(value.to_uint64())
  }
  self.write_message_field(number, packed)
}

///|
pub fn Writer::write_repeated_message(
  self : Writer,
  number : Int32,
  messages : ArrayView[Writer],
) -> Unit raise @error.MvtError {
  for message in messages {
    self.write_message_field(number, message)
  }
}

///|
fn append_bytes(output : Array[Byte], value : Bytes) -> Unit {
  for byte in value {
    output.push(byte)
  }
}
