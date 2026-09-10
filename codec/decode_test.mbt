///|
test "complete fixture round trips through the public codec" {
  let original = fixture_tile()
  let bytes = encode_tile(original)
  let decoded = decode_tile(bytes)
  assert_eq(decoded, original)
  assert_eq(encode_tile(decoded), bytes)
}

///|
test "decoder accepts an empty tile" {
  assert_eq(decode_tile(b""), @model.Tile::empty())
}

///|
test "decoder accepts a mapbox-vector-tile 2.2.0 fixture" {
  let bytes = b"\x1a\x37\x0a\x07interop\x12\x0f\x08\x2a\x12\x04\x00\x00\x01\x01\x18\x01\x22\x03\x09\x0e\x16\x1a\x04name\x1a\x02ok\x22\x08\x0a\x06python\x22\x02\x38\x01\x28\x80\x20\x78\x02"
  let tile = decode_tile(bytes)
  let layer = tile.layers[0]
  let feature = layer.features[0]
  assert_eq(layer.name, "interop")
  assert_eq(layer.extent, 4096)
  assert_eq(feature.id, Some(42UL))
  assert_eq(layer.resolve_properties(feature), [
    { key: "name", value: @model.MvtValue::StringValue("python"), },
    { key: "ok", value: @model.MvtValue::BoolValue(true), },
  ])
  assert_eq(
    @geometry.decode_geometry(feature.geometry_type, feature.geometry).paths[0].points,
    [@model.Point::new(7, 11)],
  )
}

///|
test "decoder skips unknown fields at every message level" {
  let value = @wire.Writer::new()
  value.write_string_field(1, "road")
  value.write_varint_field(100, 1UL)
  let feature = @wire.Writer::new()
  feature.write_varint_field(3, 0UL)
  feature.write_varint_field(100, 2UL)
  let layer = @wire.Writer::new()
  layer.write_string_field(1, "x")
  layer.write_message_field(2, feature)
  layer.write_string_field(3, "class")
  layer.write_message_field(4, value)
  layer.write_varint_field(5, 4096UL)
  layer.write_varint_field(15, 2UL)
  layer.write_varint_field(100, 3UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  tile.write_varint_field(100, 4UL)
  let decoded = decode_tile(tile.finish())
  assert_eq(decoded.layers[0].name, "x")
  assert_eq(decoded.layers[0].values, [@model.MvtValue::StringValue("road")])
}

///|
test "decoder rejects missing required layer fields" {
  let no_name = @wire.Writer::new()
  no_name.write_varint_field(15, 2UL)
  let no_version = @wire.Writer::new()
  no_version.write_string_field(1, "x")
  for layer in [no_name, no_version] {
    let tile = @wire.Writer::new()
    tile.write_message_field(3, layer)
    let mut rejected = false
    ignore(decode_tile(tile.finish())) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "decoder rejects duplicate singular fields" {
  let layer = @wire.Writer::new()
  layer.write_string_field(1, "x")
  layer.write_string_field(1, "y")
  layer.write_varint_field(15, 2UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  let mut rejected = false
  ignore(decode_tile(tile.finish())) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "decoder rejects a value with zero or multiple variants" {
  let empty = @wire.Writer::new()
  let multiple = @wire.Writer::new()
  multiple.write_string_field(1, "x")
  multiple.write_varint_field(7, 1UL)
  for value in [empty, multiple] {
    let layer = @wire.Writer::new()
    layer.write_string_field(1, "x")
    layer.write_message_field(4, value)
    layer.write_varint_field(15, 2UL)
    let tile = @wire.Writer::new()
    tile.write_message_field(3, layer)
    let mut rejected = false
    ignore(decode_tile(tile.finish())) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "decoder rejects noncanonical boolean payload" {
  let value = @wire.Writer::new()
  value.write_varint_field(7, 2UL)
  let layer = @wire.Writer::new()
  layer.write_string_field(1, "x")
  layer.write_message_field(4, value)
  layer.write_varint_field(15, 2UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  let mut rejected = false
  ignore(decode_tile(tile.finish())) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "decoder rejects a wire type mismatch" {
  let layer = @wire.Writer::new()
  layer.write_varint_field(1, 1UL)
  layer.write_varint_field(15, 2UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  let mut rejected = false
  ignore(decode_tile(tile.finish())) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "decoder enforces layer and feature count limits" {
  let standard = @limits.DecodeLimits::constrained()
  let one_layer : @limits.DecodeLimits = { ..standard, max_layers: 1, }
  let layer = @wire.Writer::new()
  layer.write_string_field(1, "x")
  layer.write_varint_field(15, 2UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  tile.write_message_field(3, layer)
  let mut rejected = false
  ignore(decode_tile(tile.finish(), limits=one_layer)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "decoder enforces packed geometry word limits" {
  let standard = @limits.DecodeLimits::constrained()
  let tiny : @limits.DecodeLimits = {
    ..standard,
    max_geometry_words_per_feature: 2,
  }
  let feature = @wire.Writer::new()
  feature.write_varint_field(3, 1UL)
  feature.write_packed_words(4, [9U, 0U, 0U])
  let layer = @wire.Writer::new()
  layer.write_string_field(1, "x")
  layer.write_message_field(2, feature)
  layer.write_varint_field(15, 2UL)
  let tile = @wire.Writer::new()
  tile.write_message_field(3, layer)
  let mut rejected = false
  ignore(decode_tile(tile.finish(), limits=tiny)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "decoder preserves all numeric value variants" {
  let original = fixture_tile()
  let variants : Array[@model.MvtValue] = [
    @model.MvtValue::FloatValue(Float::reinterpret_from_uint(0x7fc00001U)),
    @model.MvtValue::DoubleValue(-0.0),
    @model.MvtValue::IntValue(-9223372036854775807L - 1L),
    @model.MvtValue::UIntValue(0xffffffffffffffffUL),
    @model.MvtValue::SIntValue(-9223372036854775807L - 1L),
    @model.MvtValue::BoolValue(false),
  ]
  let tile : @model.Tile = {
    layers: [{ ..original.layers[0], values: variants, features: [], }],
  }
  let decoded = decode_tile(encode_tile(tile))
  assert_eq(decoded.layers[0].values.length(), variants.length())
  for index, value in variants {
    assert_true(decoded.layers[0].values[index].dictionary_equal(value))
  }
}
