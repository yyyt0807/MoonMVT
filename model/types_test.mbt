///|
test "geometry type number mapping is total for MVT values" {
  for pair in [
    (GeomType::Unknown, 0),
    (GeomType::Point, 1),
    (GeomType::LineString, 2),
    (GeomType::Polygon, 3),
  ] {
    let (kind, number) = pair
    assert_eq(kind.number(), number)
    assert_eq(GeomType::from_number(number, "type"), kind)
  }
  let mut rejected = false
  ignore(GeomType::from_number(4, "type")) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "point and bounds operations use tile-local coordinates" {
  let origin = Point::new(10, 20)
  let moved = origin.translate(-15, 7)
  assert_eq(moved, { x: -5, y: 27 })
  assert_eq(origin.manhattan_distance(moved), 22L)
  let bounds = Bounds::from_point(origin).include_point(moved).include_point(Point::new(30, 0))
  assert_eq(bounds, { min_x: -5, min_y: 0, max_x: 30, max_y: 27 })
  assert_eq(bounds.width(), 35L)
  assert_eq(bounds.height(), 27L)
  assert_true(bounds.contains(Point::new(0, 1)))
  assert_false(bounds.contains(Point::new(31, 1)))
}

///|
test "feature id helpers preserve the remaining model" {
  let feature = Feature::empty(GeomType::Point)
  assert_eq(feature.id, None)
  let identified = feature.with_id(42UL)
  assert_eq(identified.id, Some(42UL))
  assert_eq(identified.without_id(), feature)
}

///|
test "property resolution follows tag order" {
  let layer : Layer = {
    name: "roads",
    features: [],
    keys: ["class", "name"],
    values: [MvtValue::StringValue("primary"), MvtValue::StringValue("Main")],
    extent: 4096,
    version: 2,
  }
  let feature : Feature = {
    id: Some(1UL),
    tags: [1, 1, 0, 0],
    geometry_type: GeomType::LineString,
    geometry: [],
  }
  assert_eq(
    layer.resolve_properties(feature),
    [
      { key: "name", value: MvtValue::StringValue("Main") },
      { key: "class", value: MvtValue::StringValue("primary") },
    ],
  )
  assert_eq(layer.property(feature, "class"), Some(MvtValue::StringValue("primary")))
  assert_eq(layer.property(feature, "missing"), None)
}

///|
test "property resolution rejects malformed indexes" {
  let layer : Layer = {
    name: "x",
    features: [],
    keys: ["a"],
    values: [MvtValue::BoolValue(true)],
    extent: 4096,
    version: 2,
  }
  let odd : Feature = { ..Feature::empty(GeomType::Point), tags: [0] }
  let bad_key : Feature = { ..odd, tags: [1, 0] }
  let bad_value : Feature = { ..odd, tags: [0, 1] }
  for feature in [odd, bad_key, bad_value] {
    let mut rejected = false
    ignore(layer.resolve_properties(feature)) catch { _ => rejected = true }
    assert_true(rejected)
  }
}

///|
test "tile access and summaries retain stable order" {
  let point = Feature::empty(GeomType::Point).with_id(7UL)
  let polygon = Feature::empty(GeomType::Polygon)
  let roads : Layer = { ..Layer::empty("roads"), features: [point] }
  let land : Layer = { ..Layer::empty("land"), features: [polygon] }
  let tile : Tile = { layers: [roads, land] }
  assert_eq(tile.layer_by_name("roads"), Some(roads))
  assert_eq(tile.layer_by_name("water"), None)
  assert_eq(roads.feature_by_id(7UL), Some(point))
  assert_eq(
    tile.summary(),
    {
      layers: 2,
      features: 2,
      points: 1,
      lines: 0,
      polygons: 1,
      unknown_geometries: 0,
      geometry_words: 0,
    },
  )
}

///|
test "filtering layers and features preserves order" {
  let first = Feature::empty(GeomType::Point).with_id(1UL)
  let second = Feature::empty(GeomType::Point).with_id(2UL)
  let roads : Layer = { ..Layer::empty("roads"), features: [first, second] }
  let water = Layer::empty("water")
  let tile : Tile = { layers: [roads, water] }
  assert_eq(tile.filter_layers(layer => layer.name == "roads").layers, [roads])
  assert_eq(
    roads.filter_features(feature => feature.id == Some(2UL)).features,
    [second],
  )
}
