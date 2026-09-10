///|
test "point command stream round trips" {
  let points = [
    @model.Point::new(25, 17),
    @model.Point::new(30, 10),
    @model.Point::new(-2, 80),
  ]
  let words = encode_points(points)
  let decoded = decode_geometry(@model.GeomType::Point, words)
  assert_eq(decoded.paths, [Path::open(points)])
  assert_eq(encode_decoded(decoded), words)
}

///|
test "multipart line command stream round trips" {
  let lines = [
    [@model.Point::new(1, 2), @model.Point::new(3, 4), @model.Point::new(5, 8)],
    [@model.Point::new(20, 30), @model.Point::new(18, 40)],
  ]
  let words = encode_lines(lines)
  let decoded = decode_geometry(@model.GeomType::LineString, words)
  assert_eq(decoded.paths, [Path::open(lines[0]), Path::open(lines[1])])
  assert_eq(encode_decoded(decoded), words)
}

///|
test "polygon command stream round trips without duplicate closure point" {
  let rings = [
    [
      @model.Point::new(0, 0),
      @model.Point::new(10, 0),
      @model.Point::new(10, 10),
      @model.Point::new(0, 10),
    ],
    [
      @model.Point::new(2, 2),
      @model.Point::new(2, 5),
      @model.Point::new(5, 5),
      @model.Point::new(5, 2),
    ],
  ]
  let words = encode_polygons(rings)
  let decoded = decode_geometry(@model.GeomType::Polygon, words)
  assert_eq(decoded.paths, [Path::closed(rings[0]), Path::closed(rings[1])])
  assert_eq(encode_decoded(decoded), words)
  validate_polygon_rings(decoded)
}

///|
test "unknown geometry accepts only an empty stream" {
  assert_eq(decode_geometry(@model.GeomType::Unknown, []), {
    geometry_type: @model.GeomType::Unknown,
    paths: [],
  })
  let mut rejected = false
  ignore(decode_geometry(@model.GeomType::Unknown, [9U, 0U, 0U])) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "geometry grammar rejects misplaced commands" {
  let invalid : Array[(@model.GeomType, Array[UInt])] = [
    (@model.GeomType::Point, [10U, 0U, 0U]),
    (@model.GeomType::LineString, [17U, 0U, 0U, 0U, 0U, 10U, 1U, 1U]),
    (@model.GeomType::LineString, [9U, 0U, 0U]),
    (@model.GeomType::Polygon, [9U, 0U, 0U, 10U, 1U, 1U, 15U]),
    (@model.GeomType::Polygon, [9U, 0U, 0U, 18U, 1U, 1U, 1U, 1U]),
    (@model.GeomType::Polygon, [9U, 0U, 0U, 18U, 1U, 1U, 1U, 1U, 23U]),
  ]
  for item in invalid {
    let (kind, words) = item
    let mut rejected = false
    ignore(decode_geometry(kind, words)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "geometry decoder rejects truncated coordinate pairs" {
  let invalid = [[9U], [9U, 2U], [17U, 2U, 2U], [17U, 2U, 2U, 2U]]
  for words in invalid {
    let mut rejected = false
    ignore(decode_geometry(@model.GeomType::Point, words)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "geometry decoder rejects coordinate accumulation overflow" {
  let words = [
    command_header(CommandId::MoveTo, 2),
    @wire.zigzag_encode_i32(2147483647),
    0U,
    @wire.zigzag_encode_i32(1),
    0U,
  ]
  let mut rejected = false
  ignore(decode_geometry(@model.GeomType::Point, words)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "ring analysis follows screen-coordinate winding" {
  let clockwise = Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(10, 0),
    @model.Point::new(10, 10),
    @model.Point::new(0, 10),
  ])
  let counterclockwise = Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(0, 10),
    @model.Point::new(10, 10),
    @model.Point::new(10, 0),
  ])
  assert_eq(ring_winding(clockwise), RingWinding::Clockwise)
  assert_eq(ring_winding(counterclockwise), RingWinding::CounterClockwise)
  assert_eq(signed_ring_area2(clockwise), 200.0)
  assert_eq(signed_ring_area2(counterclockwise), -200.0)
}

///|
test "geometry analysis reports bounds duplicates and lengths" {
  let path = Path::open([
    @model.Point::new(-2, 5),
    @model.Point::new(3, 5),
    @model.Point::new(3, 5),
    @model.Point::new(3, 9),
  ])
  let geometry : DecodedGeometry = {
    geometry_type: @model.GeomType::LineString,
    paths: [path],
  }
  assert_eq(
    geometry_bounds(geometry),
    Some({ min_x: -2, min_y: 5, max_x: 3, max_y: 9, }),
  )
  assert_eq(path_duplicate_step_count(path), 1)
  assert_eq(path_distinct_point_count(path), 3)
  assert_eq(path_manhattan_length(path), 9L)
}

///|
test "polygon ring validator rejects hole before exterior and zero area" {
  let hole = Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(0, 10),
    @model.Point::new(10, 10),
    @model.Point::new(10, 0),
  ])
  let flat = Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(1, 0),
    @model.Point::new(2, 0),
  ])
  for ring in [hole, flat] {
    let geometry : DecodedGeometry = {
      geometry_type: @model.GeomType::Polygon,
      paths: [ring],
    }
    let mut rejected = false
    validate_polygon_rings(geometry) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
