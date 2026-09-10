///|
test "layer builder interns keys and typed values by first appearance" {
  let builder = LayerBuilder::new("places")
  builder.add_points(
    [@model.Point::new(1, 2)],
    properties=[
      property("name", @model.MvtValue::StringValue("Harbor")),
      property("capital", @model.MvtValue::BoolValue(true)),
    ],
    id=Some(1UL),
  )
  builder.add_points(
    [@model.Point::new(3, 4)],
    properties=[
      property("name", @model.MvtValue::StringValue("Harbor")),
      property("population", @model.MvtValue::UIntValue(12UL)),
    ],
  )
  let layer = builder.finish()
  assert_eq(layer.keys, ["name", "capital", "population"])
  assert_eq(
    layer.values,
    [
      @model.MvtValue::StringValue("Harbor"),
      @model.MvtValue::BoolValue(true),
      @model.MvtValue::UIntValue(12UL),
    ],
  )
  assert_eq(layer.features[0].tags, [0, 0, 1, 1])
  assert_eq(layer.features[1].tags, [0, 0, 2, 2])
}

///|
test "finish returns a snapshot independent of later additions" {
  let builder = LayerBuilder::new("places")
  builder.add_points([@model.Point::new(1, 1)])
  let first = builder.finish()
  builder.add_points([@model.Point::new(2, 2)])
  let second = builder.finish()
  assert_eq(first.features.length(), 1)
  assert_eq(second.features.length(), 2)
}

///|
test "builder constructs point line and polygon geometries" {
  let builder = LayerBuilder::new("mixed")
  builder.add_points([@model.Point::new(1, 1)])
  builder.add_lines([
    [@model.Point::new(0, 0), @model.Point::new(4, 4)],
  ])
  builder.add_polygons([
    [
      @model.Point::new(0, 0),
      @model.Point::new(5, 0),
      @model.Point::new(5, 5),
      @model.Point::new(0, 5),
    ],
  ])
  let layer = builder.finish()
  assert_eq(layer.features.length(), 3)
  assert_eq(layer.features[0].geometry_type, @model.GeomType::Point)
  assert_eq(layer.features[1].geometry_type, @model.GeomType::LineString)
  assert_eq(layer.features[2].geometry_type, @model.GeomType::Polygon)
}

///|
test "builder rejects duplicate property names within one feature" {
  let builder = LayerBuilder::new("x")
  let mut rejected = false
  builder.add_points(
    [@model.Point::new(0, 0)],
    properties=[
      property("name", @model.MvtValue::StringValue("a")),
      property("name", @model.MvtValue::StringValue("b")),
    ],
  ) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  assert_eq(builder.feature_count(), 0)
}

///|
test "failed feature addition does not partially intern dictionaries" {
  let builder = LayerBuilder::new("x")
  let invalid = FeatureInput::raw(
    @model.GeomType::LineString,
    [9U, 0U, 0U],
    properties=[property("name", @model.MvtValue::StringValue("bad"))],
  )
  let mut rejected = false
  builder.add_feature(invalid) catch { _ => rejected = true }
  assert_true(rejected)
  assert_eq(builder.key_count(), 0)
  assert_eq(builder.value_count(), 0)
}

///|
test "tile builder rejects duplicate layer names" {
  let tile = TileBuilder::new()
  tile.add_built_layer(LayerBuilder::new("roads"))
  let mut rejected = false
  tile.add_built_layer(LayerBuilder::new("roads")) catch { _ => rejected = true }
  assert_true(rejected)
  assert_eq(tile.layer_count(), 1)
}

///|
test "compact layer removes unused and duplicate dictionary entries" {
  let feature : @model.Feature = {
    id: Some(1UL),
    tags: [1, 1, 0, 0],
    geometry_type: @model.GeomType::Point,
    geometry: @geometry.encode_points([@model.Point::new(1, 1)]),
  }
  let layer : @model.Layer = {
    name: "places",
    features: [feature],
    keys: ["name", "name", "unused"],
    values: [
      @model.MvtValue::StringValue("Harbor"),
      @model.MvtValue::StringValue("Harbor"),
      @model.MvtValue::BoolValue(false),
    ],
    extent: 4096,
    version: 2,
  }
  let compacted = compact_layer(layer)
  assert_eq(compacted.keys, ["name"])
  assert_eq(compacted.values, [@model.MvtValue::StringValue("Harbor")])
  assert_eq(compacted.features[0].tags, [0, 0, 0, 0])
}

///|
test "float dictionary interning preserves distinct NaN payloads" {
  let builder = LayerBuilder::new("values")
  let a = Float::reinterpret_from_uint(0x7fc00001U)
  let b = Float::reinterpret_from_uint(0x7fc00002U)
  assert_eq(builder.intern_value(@model.MvtValue::FloatValue(a)), 0)
  assert_eq(builder.intern_value(@model.MvtValue::FloatValue(a)), 0)
  assert_eq(builder.intern_value(@model.MvtValue::FloatValue(b)), 1)
}

