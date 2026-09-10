///|
test "encoder output is canonical" {
  let bytes = encode_tile(fixture_tile())
  let result = canonicalize(bytes)
  assert_false(result.changed)
  assert_eq(result.bytes, bytes)
  assert_eq(result.input_bytes, result.output_bytes)
  assert_true(is_canonical(bytes))
}

///|
test "canonicalization removes unknown tile fields" {
  let base = encode_tile(fixture_tile()).to_array()
  base.push(0xa0)
  base.push(0x06)
  base.push(0x01)
  let extended = Bytes::from_array(base)
  let result = canonicalize(extended)
  assert_true(result.changed)
  assert_eq(result.output_bytes + 3, result.input_bytes)
  assert_eq(result.bytes, encode_tile(fixture_tile()))
}

///|
test "canonicalization normalizes legal field order" {
  let layer = @wire.Writer::new()
  layer.write_varint_field(15, 2UL)
  layer.write_varint_field(5, 4096UL)
  layer.write_string_field(1, "x")
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  let input = tile.finish()
  let result = canonicalize(input)
  assert_true(result.changed)
  assert_eq(decode_tile(result.bytes).layers[0].name, "x")
  assert_true(is_canonical(result.bytes))
}

///|
test "canonicalization still enforces decode limits" {
  let limits : @limits.DecodeLimits = {
    ..@limits.DecodeLimits::constrained(),
    max_tile_bytes: 2,
    max_submessage_bytes: 2,
  }
  let mut rejected = false
  ignore(canonicalize(b"abc", limits~)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}
