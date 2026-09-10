///|
test "reader traverses every supported wire type" {
  let data = b"\x08\x96\x01\x11\x08\x07\x06\x05\x04\x03\x02\x01\x1a\x03abc\x25\x04\x03\x02\x01"
  let reader = Reader::new(data)
  let k1 = reader.read_key()
  assert_eq(k1, { number: 1, wire_type: WireType::Varint, })
  assert_eq(reader.read_varint("one"), 150UL)
  let k2 = reader.read_key()
  assert_eq(k2, { number: 2, wire_type: WireType::Fixed64, })
  assert_eq(reader.read_fixed64("two"), 0x0102030405060708UL)
  let k3 = reader.read_key()
  assert_eq(k3, { number: 3, wire_type: WireType::LengthDelimited, })
  assert_eq(reader.read_string("three"), "abc")
  let k4 = reader.read_key()
  assert_eq(k4, { number: 4, wire_type: WireType::Fixed32, })
  assert_eq(reader.read_fixed32("four"), 0x01020304U)
  assert_true(reader.is_done())
}

///|
test "subreader cannot consume the parent suffix" {
  let parent = Reader::new(b"\x02\x08\x01\xff")
  let child = parent.read_subreader("message")
  assert_eq(child.read_key().number, 1)
  assert_eq(child.read_varint("value"), 1UL)
  assert_true(child.is_done())
  assert_eq(parent.remaining(), 1)
}

///|
test "reader skips supported unknown fields" {
  let reader = Reader::new(
    b"\x08\x01\x11\x00\x00\x00\x00\x00\x00\x00\x00\x1a\x02xx\x25\x00\x00\x00\x00",
  )
  while !reader.is_done() {
    reader.skip_field(reader.read_key())
  }
  assert_eq(reader.unknown_field_count(), 4)
}

///|
test "packed uint32 decoding enforces word count and width" {
  let reader = Reader::new(b"\x04\x00\x7f\x80\x01")
  assert_eq(reader.read_packed_uint32("tags", 3), [0, 127, 128])
  let limited = Reader::new(b"\x02\x01\x02")
  let mut limit_rejected = false
  ignore(limited.read_packed_uint32("tags", 1)) catch {
    _ => limit_rejected = true
  }
  assert_true(limit_rejected)
  let wide = Reader::new(b"\x05\x80\x80\x80\x80\x10")
  let mut width_rejected = false
  ignore(wide.read_packed_uint32("tags", 2)) catch {
    _ => width_rejected = true
  }
  assert_true(width_rejected)
}

///|
test "bounded reader detects a varint crossing submessage boundary" {
  let parent = Reader::new(b"\x01\x80\x01")
  let child = parent.read_subreader("child")
  let mut rejected = false
  ignore(child.read_varint("child value")) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  assert_eq(parent.remaining(), 1)
}

///|
test "string reader rejects invalid UTF-8" {
  let reader = Reader::new(b"\x02\xc3\x28")
  let mut rejected = false
  ignore(reader.read_string("layer.name")) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "reader rejects length beyond remaining bytes" {
  let reader = Reader::new(b"\x05abc")
  let mut rejected = false
  ignore(reader.read_bytes("payload")) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "reader enforces top-level tile size" {
  let standard = @limits.DecodeLimits::constrained()
  let tiny : @limits.DecodeLimits = {
    ..standard,
    max_tile_bytes: 2,
    max_submessage_bytes: 2,
  }
  let mut rejected = false
  ignore(Reader::new(b"abc", limits=tiny)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "packed words preserve the full uint32 range" {
  let reader = Reader::new(b"\x06\x00\xff\xff\xff\xff\x0f")
  assert_eq(reader.read_packed_words("geometry", 2), [0U, 0xffffffffU])
}
