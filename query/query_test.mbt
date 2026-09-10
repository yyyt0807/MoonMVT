///|
fn query_fixture() -> @model.Layer raise {
  let builder = @builder.LayerBuilder::new("places")
  builder.add_points(
    [@model.Point::new(10, 20)],
    properties=[
      @builder.property("name", @model.MvtValue::StringValue("Harbor")),
      @builder.property("capital", @model.MvtValue::BoolValue(true)),
    ],
    id=Some(1UL),
  )
  builder.add_points(
    [@model.Point::new(100, 200), @model.Point::new(110, 190)],
    properties=[
      @builder.property("name", @model.MvtValue::StringValue("Market")),
      @builder.property("capital", @model.MvtValue::BoolValue(false)),
    ],
    id=Some(2UL),
  )
  builder.finish()
}

///|
test "feature views resolve properties geometry and bounds" {
  let layer = query_fixture()
  let view = inspect_feature(layer, 1)
  assert_eq(view.id, Some(2UL))
  assert_eq(view.geometry_type, @model.GeomType::Point)
  assert_eq(view.point_count, 2)
  assert_eq(view.path_count, 1)
  assert_eq(
    view.bounds,
    Some({ min_x: 100, min_y: 190, max_x: 110, max_y: 200, }),
  )
  assert_eq(view.property("name"), Some(@model.MvtValue::StringValue("Market")))
  assert_true(view.has_property("capital"))
  assert_false(view.has_property("missing"))
}

///|
test "property equality preserves MVT value kinds" {
  let view = inspect_feature(query_fixture(), 0)
  assert_true(view.property_equals("capital", @model.MvtValue::BoolValue(true)))
  assert_false(view.property_equals("capital", @model.MvtValue::UIntValue(1UL)))
}

///|
test "bounds intersection treats touching edges as intersection" {
  let view = inspect_feature(query_fixture(), 0)
  assert_true(
    view.intersects_bounds({ min_x: 10, min_y: 20, max_x: 10, max_y: 20, }),
  )
  assert_true(
    view.intersects_bounds({ min_x: 0, min_y: 0, max_x: 10, max_y: 20, }),
  )
  assert_false(
    view.intersects_bounds({ min_x: 11, min_y: 20, max_x: 20, max_y: 30, }),
  )
}

///|
test "property filters compact dictionaries" {
  let layer = query_fixture()
  let capital = filter_property_equals(
    layer,
    "capital",
    @model.MvtValue::BoolValue(true),
  )
  assert_eq(capital.features.length(), 1)
  assert_eq(capital.features[0].id, Some(1UL))
  assert_eq(capital.keys, ["name", "capital"])
  assert_eq(capital.values, [
    @model.MvtValue::StringValue("Harbor"),
    @model.MvtValue::BoolValue(true),
  ])
}

///|
test "spatial and presence filters retain feature order" {
  let layer = query_fixture()
  let all = filter_has_property(layer, "name")
  assert_eq(all.features.map(feature => feature.id), [Some(1UL), Some(2UL)])
  let distant = filter_intersects(layer, {
    min_x: 90,
    min_y: 180,
    max_x: 120,
    max_y: 220,
  })
  assert_eq(distant.features.map(feature => feature.id), [Some(2UL)])
}

///|
test "geometry type filter handles empty result" {
  let result = filter_geometry_type(query_fixture(), @model.GeomType::Polygon)
  assert_true(result.features.is_empty())
  assert_true(result.keys.is_empty())
  assert_true(result.values.is_empty())
}

///|
test "layer statistics count logical and encoded sizes" {
  let stats = layer_statistics(query_fixture())
  assert_eq(stats.name, "places")
  assert_eq(stats.features, 2)
  assert_eq(stats.point_features, 2)
  assert_eq(stats.line_features, 0)
  assert_eq(stats.properties, 4)
  assert_eq(stats.decoded_points, 3)
  assert_eq(stats.dictionary_keys, 2)
  assert_eq(stats.dictionary_values, 4)
}

///|
test "tile statistics aggregate layers in order" {
  let first = query_fixture()
  let second : @model.Layer = { ..@model.Layer::empty("empty"), extent: 256, }
  let stats = tile_statistics({ layers: [first, second], })
  assert_eq(stats.layers, 2)
  assert_eq(stats.features, 2)
  assert_eq(stats.properties, 4)
  assert_eq(stats.decoded_points, 3)
  assert_eq(stats.layer_statistics.map(item => item.name), ["places", "empty"])
}

///|
test "inspect feature rejects index outside the layer" {
  let layer = query_fixture()
  for index in [-1, 2] {
    let mut rejected = false
    ignore(inspect_feature(layer, index)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
