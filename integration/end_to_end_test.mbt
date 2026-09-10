///|
fn build_integration_tile() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("features", extent=8192)
  layer.add_points(
    [@model.Point::new(-16, 20), @model.Point::new(8200, 4000)],
    properties=[
      @builder.property("kind", @model.MvtValue::StringValue("station")),
      @builder.property("rank", @model.MvtValue::UIntValue(1UL)),
    ],
    id=Some(100UL),
  )
  layer.add_lines(
    [
      [
        @model.Point::new(-32, 100),
        @model.Point::new(4096, 4096),
        @model.Point::new(8224, 8000),
      ],
      [@model.Point::new(100, 7000), @model.Point::new(7000, 100)],
    ],
    properties=[
      @builder.property("kind", @model.MvtValue::StringValue("road")),
      @builder.property("rank", @model.MvtValue::UIntValue(2UL)),
    ],
    id=Some(101UL),
  )
  layer.add_polygons(
    [
      [
        @model.Point::new(100, 100),
        @model.Point::new(8000, 100),
        @model.Point::new(8000, 8000),
        @model.Point::new(100, 8000),
      ],
      [
        @model.Point::new(2000, 2000),
        @model.Point::new(2000, 3000),
        @model.Point::new(3000, 3000),
        @model.Point::new(3000, 2000),
      ],
    ],
    properties=[
      @builder.property("kind", @model.MvtValue::StringValue("park")),
      @builder.property("rank", @model.MvtValue::UIntValue(3UL)),
    ],
    id=Some(102UL),
  )
  { layers: [layer.finish()] }
}

///|
test "typed builders and codec form an exact logical round trip" {
  let original = build_integration_tile()
  let bytes = @codec.encode_tile(original)
  let decoded = @codec.decode_tile(bytes)
  assert_eq(decoded, original)
  assert_eq(@codec.encode_tile(decoded), bytes)
}

///|
test "buffer coordinates outside extent survive round trip" {
  let decoded = @codec.decode_tile(@codec.encode_tile(build_integration_tile()))
  let point = @query.inspect_feature(decoded.layers[0], 0)
  assert_eq(point.bounds, Some({ min_x: -16, min_y: 20, max_x: 8200, max_y: 4000 }))
}

///|
test "all three geometry types remain queryable after decode" {
  let tile = @codec.decode_tile(@codec.encode_tile(build_integration_tile()))
  let stats = @query.tile_statistics(tile)
  assert_eq(stats.features, 3)
  assert_eq(stats.layer_statistics[0].point_features, 1)
  assert_eq(stats.layer_statistics[0].line_features, 1)
  assert_eq(stats.layer_statistics[0].polygon_features, 1)
  assert_eq(stats.decoded_points, 15)
}

///|
test "filtered output has compact properties and stays canonical" {
  let tile = @codec.decode_tile(@codec.encode_tile(build_integration_tile()))
  let roads = @query.filter_property_equals(
    tile.layers[0],
    "kind",
    @model.MvtValue::StringValue("road"),
  )
  assert_eq(roads.features.length(), 1)
  assert_eq(roads.keys, ["kind", "rank"])
  assert_eq(
    roads.values,
    [
      @model.MvtValue::StringValue("road"),
      @model.MvtValue::UIntValue(2UL),
    ],
  )
  let bytes = @codec.encode_tile({ layers: [roads] })
  assert_true(@codec.is_canonical(bytes))
}

///|
test "decoder rejects truncated prefixes of a valid tile" {
  let bytes = @codec.encode_tile(build_integration_tile())
  let mut rejected = 0
  for length in 1..<bytes.length() {
    ignore(@codec.decode_tile(bytes[0:length].to_owned())) catch {
      _ => rejected += 1
    }
  }
  assert_eq(rejected, bytes.length() - 1)
}

///|
test "decoder result does not alias mutable encoder inputs" {
  let tile = build_integration_tile()
  let bytes = @codec.encode_tile(tile)
  let decoded = @codec.decode_tile(bytes)
  tile.layers[0].features[0].geometry[1] = 999U
  assert_true(decoded.layers[0].features[0].geometry[1] != 999U)
}

///|
test "wire unknown groups are rejected instead of skipped ambiguously" {
  let mut rejected = false
  ignore(@codec.decode_tile(b"\x0b\x0c")) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "constrained limits still accept a normal application tile" {
  let bytes = @codec.encode_tile(build_integration_tile())
  let tile = @codec.decode_tile(bytes, limits=@limits.DecodeLimits::constrained())
  assert_eq(tile.layers.length(), 1)
  assert_eq(tile.layers[0].features.length(), 3)
}
