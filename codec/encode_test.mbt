///|
fn fixture_tile() -> @model.Tile raise {
  let point_words = @geometry.encode_points([
    @model.Point::new(25, 17),
    @model.Point::new(30, 10),
  ])
  let line_words = @geometry.encode_lines([
    [@model.Point::new(2, 2), @model.Point::new(5, 7)],
  ])
  {
    layers: [
      {
        name: "places",
        features: [
          {
            id: Some(101UL),
            tags: [0, 0, 1, 1],
            geometry_type: @model.GeomType::Point,
            geometry: point_words,
          },
        ],
        keys: ["name", "capital"],
        values: [
          @model.MvtValue::StringValue("Harbor"),
          @model.MvtValue::BoolValue(true),
        ],
        extent: 4096,
        version: 2,
      },
      {
        name: "roads",
        features: [
          {
            id: None,
            tags: [],
            geometry_type: @model.GeomType::LineString,
            geometry: line_words,
          },
        ],
        keys: [],
        values: [],
        extent: 256,
        version: 2,
      },
    ],
  }
}

///|
test "encoding is deterministic for the same model" {
  let tile = fixture_tile()
  let first = encode_tile(tile)
  let second = encode_tile(tile)
  assert_eq(first, second)
  assert_true(first.length() > 0)
}

///|
test "empty tile encodes as an empty protobuf document" {
  assert_eq(encode_tile(@model.Tile::empty()), b"")
}

///|
test "simple point tile has stable golden bytes" {
  let tile : @model.Tile = {
    layers: [
      {
        name: "x",
        features: [
          {
            id: Some(1UL),
            tags: [],
            geometry_type: @model.GeomType::Point,
            geometry: [9U, 2U, 4U],
          },
        ],
        keys: [],
        values: [],
        extent: 4096,
        version: 2,
      },
    ],
  }
  assert_eq(
    encode_tile(tile),
    b"\x1a\x13\x0a\x01x\x12\x09\x08\x01\x18\x01\x22\x03\x09\x02\x04\x28\x80\x20\x78\x02",
  )
}

///|
test "all value variants encode one schema field" {
  let variants : Array[@model.MvtValue] = [
    @model.MvtValue::StringValue("x"),
    @model.MvtValue::FloatValue(1.5),
    @model.MvtValue::DoubleValue(-2.5),
    @model.MvtValue::IntValue(-3L),
    @model.MvtValue::UIntValue(4UL),
    @model.MvtValue::SIntValue(-5L),
    @model.MvtValue::BoolValue(true),
  ]
  for value in variants {
    let tile : @model.Tile = {
      layers: [
        {
          ..@model.Layer::empty("values"),
          values: [value],
        },
      ],
    }
    assert_true(encode_tile(tile).length() > 0)
  }
}

///|
test "validation rejects duplicate and empty layer names" {
  let empty = @model.Layer::empty("")
  let mut empty_rejected = false
  ignore(encode_tile({ layers: [empty] })) catch { _ => empty_rejected = true }
  assert_true(empty_rejected)
  let repeated = @model.Layer::empty("roads")
  let mut duplicate_rejected = false
  ignore(encode_tile({ layers: [repeated, repeated] })) catch {
    _ => duplicate_rejected = true
  }
  assert_true(duplicate_rejected)
}

///|
test "validation rejects unsupported version and extent" {
  let base = @model.Layer::empty("roads")
  let invalid = [{ ..base, version: 1 }, { ..base, extent: 0 }]
  for layer in invalid {
    let mut rejected = false
    ignore(encode_tile({ layers: [layer] })) catch { _ => rejected = true }
    assert_true(rejected)
  }
}

///|
test "validation rejects bad property references" {
  let feature : @model.Feature = {
    ..@model.Feature::empty(@model.GeomType::Unknown),
    tags: [0, 0],
  }
  let layer : @model.Layer = { ..@model.Layer::empty("x"), features: [feature] }
  let mut rejected = false
  ignore(encode_tile({ layers: [layer] })) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "validation rejects malformed geometry before writing bytes" {
  let feature : @model.Feature = {
    id: None,
    tags: [],
    geometry_type: @model.GeomType::LineString,
    geometry: [9U, 0U, 0U],
  }
  let layer : @model.Layer = { ..@model.Layer::empty("x"), features: [feature] }
  let mut rejected = false
  ignore(encode_tile({ layers: [layer] })) catch { _ => rejected = true }
  assert_true(rejected)
}
