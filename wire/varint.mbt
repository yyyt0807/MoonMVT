///|
/// Maximum number of bytes in one protobuf UInt64 varint.
pub let max_varint_bytes : Int = 10

///|
/// Encode an unsigned protobuf varint using its shortest representation.
pub fn encode_varint(value : UInt64) -> Bytes {
  let output : Array[Byte] = []
  append_varint(output, value)
  Bytes::from_array(output)
}

///|
/// Append an unsigned protobuf varint to an existing byte array.
pub fn append_varint(output : Array[Byte], initial : UInt64) -> Unit {
  let mut value = initial
  while value >= 0x80UL {
    output.push(((value & 0x7fUL).to_int() | 0x80).to_byte())
    value = value >> 7
  }
  output.push(value.to_int().to_byte())
}

///|
/// Decode one protobuf varint at `offset`, returning the value and next offset.
/// Overlong and overflowing encodings are rejected.
pub fn decode_varint(
  data : Bytes,
  offset : Int,
) -> (UInt64, Int) raise @error.MvtError {
  if offset < 0 || offset > data.length() {
    raise @error.MvtError::InvalidArgument("varint offset is outside input")
  }
  let mut value = 0UL
  let mut shift = 0
  let mut cursor = offset
  while cursor < data.length() && shift < 70 {
    let byte = data[cursor]
    let payload = (byte.to_int() & 0x7f).to_uint64()
    if shift == 63 && payload > 1UL {
      raise @error.MvtError::NumericOverflow(path="protobuf varint")
    }
    if shift > 63 && payload != 0UL {
      raise @error.MvtError::NumericOverflow(path="protobuf varint")
    }
    value = value | (payload << shift)
    cursor += 1
    if (byte.to_int() & 0x80) == 0 {
      let used = cursor - offset
      if used != varint_length(value) {
        raise @error.MvtError::InvalidWire(
          offset~,
          detail="non-canonical varint encoding",
        )
      }
      return (value, cursor)
    }
    shift += 7
  }
  if cursor >= data.length() {
    raise @error.MvtError::TruncatedInput(offset=cursor, context="varint")
  }
  raise @error.MvtError::NumericOverflow(path="protobuf varint")
}

///|
/// Number of bytes in the canonical varint representation.
pub fn varint_length(initial : UInt64) -> Int {
  let mut value = initial
  let mut length = 1
  while value >= 0x80UL {
    value = value >> 7
    length += 1
  }
  length
}

///|
/// Encode a signed integer with the zigzag transform used by MVT geometry.
pub fn zigzag_encode_i64(value : Int64) -> UInt64 {
  if value >= 0L {
    value.reinterpret_as_uint64() * 2UL
  } else {
    (-(value + 1L)).reinterpret_as_uint64() * 2UL + 1UL
  }
}

///|
/// Decode a zigzag transformed signed integer.
pub fn zigzag_decode_i64(value : UInt64) -> Int64 {
  if (value & 1UL) == 0UL {
    (value >> 1).reinterpret_as_int64()
  } else {
    -(value >> 1).reinterpret_as_int64() - 1L
  }
}

///|
pub fn zigzag_encode_i32(value : Int) -> UInt {
  if value >= 0 {
    value.reinterpret_as_uint() * 2U
  } else {
    (-(value + 1)).reinterpret_as_uint() * 2U + 1U
  }
}

///|
pub fn zigzag_decode_i32(value : UInt) -> Int {
  if (value & 1U) == 0U {
    (value >> 1).reinterpret_as_int()
  } else {
    -(value >> 1).reinterpret_as_int() - 1
  }
}

///|
/// Construct a protobuf field key.
pub fn encode_field_key(
  number : Int,
  wire_type : WireType,
) -> UInt64 raise @error.MvtError {
  if number <= 0 || number > 536870911 {
    raise @error.MvtError::InvalidArgument(
      "protobuf field number must be in 1..536870911",
    )
  }
  (number.to_uint64() << 3) | wire_type_number(wire_type).to_uint64()
}

///|
/// Split a raw protobuf field key into its validated number and wire type.
pub fn decode_field_key(
  raw : UInt64,
  offset : Int,
) -> FieldKey raise @error.MvtError {
  let number64 = raw >> 3
  if number64 == 0UL || number64 > 536870911UL {
    raise @error.MvtError::InvalidWire(
      offset~,
      detail="field number is outside 1..536870911",
    )
  }
  {
    number: number64.to_int(),
    wire_type: wire_type_from_number((raw & 7UL).to_int(), offset),
  }
}
