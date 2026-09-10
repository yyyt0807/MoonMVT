///|
test "varint canonical vectors" {
  let vectors : Array[(UInt64, Bytes)] = [
    (0UL, b"\x00"),
    (1UL, b"\x01"),
    (127UL, b"\x7f"),
    (128UL, b"\x80\x01"),
    (300UL, b"\xac\x02"),
    (16384UL, b"\x80\x80\x01"),
    (0xffffffffUL, b"\xff\xff\xff\xff\x0f"),
    (0xffffffffffffffffUL, b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01"),
  ]
  for vector in vectors {
    let (value, encoded) = vector
    assert_eq(encode_varint(value), encoded)
    let (decoded, next) = decode_varint(encoded, 0)
    assert_eq(decoded, value)
    assert_eq(next, encoded.length())
    assert_eq(varint_length(value), encoded.length())
  }
}

///|
test "varint round trips boundary neighborhoods" {
  let values : Array[UInt64] = [
    0UL, 1UL, 2UL, 126UL, 127UL, 128UL, 129UL, 16383UL, 16384UL, 16385UL, 2097151UL,
    2097152UL, 0x7fffffffUL, 0x80000000UL, 0x7fffffffffffffffUL, 0xffffffffffffffffUL,
  ]
  for value in values {
    let bytes = encode_varint(value)
    let (decoded, next) = decode_varint(bytes, 0)
    assert_eq(decoded, value)
    assert_eq(next, bytes.length())
  }
}

///|
test "varint supports nonzero offsets" {
  let data = b"\xaa\xbb\xac\x02\xcc"
  let (value, next) = decode_varint(data, 2)
  assert_eq(value, 300UL)
  assert_eq(next, 4)
}

///|
test "varint rejects truncation overflow and noncanonical encodings" {
  let invalid : Array[Bytes] = [
    b"\x80", b"\x81\x00", b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x02", b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x00",
  ]
  for data in invalid {
    let mut rejected = false
    ignore(decode_varint(data, 0)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "zigzag signed boundaries round trip" {
  let values : Array[Int64] = [
    -9223372036854775807L - 1L,
    -9223372036854775807L,
    -123456789L,
    -2L,
    -1L,
    0L,
    1L,
    2L,
    123456789L,
    9223372036854775807L,
  ]
  for value in values {
    assert_eq(zigzag_decode_i64(zigzag_encode_i64(value)), value)
  }
  assert_eq(zigzag_encode_i64(-1L), 1UL)
  assert_eq(zigzag_encode_i64(1L), 2UL)
}

///|
test "zigzag Int values round trip" {
  let values = [-2147483647 - 1, -1000, -1, 0, 1, 1000, 2147483647]
  for value in values {
    assert_eq(zigzag_decode_i32(zigzag_encode_i32(value)), value)
  }
}

///|
test "field keys validate number and wire type" {
  let raw = encode_field_key(15, WireType::LengthDelimited)
  assert_eq(raw, 122UL)
  assert_eq(decode_field_key(raw, 0), {
    number: 15,
    wire_type: WireType::LengthDelimited,
  })
  let mut zero_rejected = false
  ignore(decode_field_key(0UL, 4)) catch {
    _ => zero_rejected = true
  }
  assert_true(zero_rejected)
  let mut group_rejected = false
  ignore(decode_field_key(11UL, 0)) catch {
    _ => group_rejected = true
  }
  assert_true(group_rejected)
}
