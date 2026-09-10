///|
test "writer emits every supported wire type" {
  let writer = Writer::new()
  writer.write_varint_field(1, 150UL)
  writer.write_fixed64_field(2, 0x0102030405060708UL)
  writer.write_string_field(3, "abc")
  writer.write_fixed32_field(4, 0x01020304U)
  assert_eq(
    writer.finish(),
    b"\x08\x96\x01\x11\x08\x07\x06\x05\x04\x03\x02\x01\x1a\x03abc\x25\x04\x03\x02\x01",
  )
}

///|
test "writer output is an owned snapshot" {
  let writer = Writer::new()
  writer.write_varint_field(1, 1UL)
  let first = writer.finish()
  writer.write_varint_field(2, 2UL)
  assert_eq(first, b"\x08\x01")
  assert_eq(writer.finish(), b"\x08\x01\x10\x02")
}

///|
test "nested messages are length delimited" {
  let child = Writer::new()
  child.write_varint_field(1, 42UL)
  let parent = Writer::new()
  parent.write_message_field(3, child)
  assert_eq(parent.finish(), b"\x1a\x02\x08\x2a")
}

///|
test "packed uint32 uses canonical varints" {
  let writer = Writer::new()
  writer.write_packed_uint32(2, [0, 127, 128, 16384])
  assert_eq(writer.finish(), b"\x12\x07\x00\x7f\x80\x01\x80\x80\x01")
  let empty = Writer::new()
  empty.write_packed_uint32(2, [])
  assert_true(empty.is_empty())
}

///|
test "packed uint32 rejects negative caller values" {
  let writer = Writer::new()
  let mut rejected = false
  writer.write_packed_uint32(1, [0, -1]) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "signed field uses zigzag transform" {
  let writer = Writer::new()
  writer.write_sint64_field(1, -1L)
  writer.write_sint64_field(2, 1L)
  assert_eq(writer.finish(), b"\x08\x01\x10\x02")
}

///|
test "writer rejects illegal field numbers" {
  let writer = Writer::new()
  let mut zero_rejected = false
  writer.write_varint_field(0, 1UL) catch { _ => zero_rejected = true }
  assert_true(zero_rejected)
  let mut high_rejected = false
  writer.write_varint_field(536870912, 1UL) catch { _ => high_rejected = true }
  assert_true(high_rejected)
}

///|
test "writer and reader agree on mixed document" {
  let writer = Writer::new()
  writer.write_varint_field(8, 99UL)
  writer.write_fixed32_field(9, 0xaabbccddU)
  writer.write_fixed64_field(10, 0x1122334455667788UL)
  writer.write_bytes_field(11, b"payload")
  let reader = Reader::new(writer.finish())
  let first = reader.read_key()
  assert_eq(first.number, 8)
  assert_eq(reader.read_varint("first"), 99UL)
  let second = reader.read_key()
  assert_eq(second.number, 9)
  assert_eq(reader.read_fixed32("second"), 0xaabbccddU)
  let third = reader.read_key()
  assert_eq(third.number, 10)
  assert_eq(reader.read_fixed64("third"), 0x1122334455667788UL)
  let fourth = reader.read_key()
  assert_eq(fourth.number, 11)
  assert_eq(reader.read_bytes("fourth"), b"payload")
  assert_true(reader.is_done())
}

///|
test "packed word writer preserves unsigned high values" {
  let writer = Writer::new()
  writer.write_packed_words(4, [0U, 0xffffffffU])
  let reader = Reader::new(writer.finish())
  let key = reader.read_key()
  assert_eq(key, { number: 4, wire_type: WireType::LengthDelimited })
  assert_eq(reader.read_packed_words("geometry", 2), [0U, 0xffffffffU])
}
