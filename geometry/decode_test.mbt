///|
test "point command stream round trips" {
  let points = [
    @model.Point::new(25, 17),
    @model.Point::new(30, 10),
    @model.Point::new(-2, 80),
  ]
  let words = @geometry.encode_points(points)
  let decoded = @geometry.decode_geometry(@model.GeomType::Point, words)
  assert_eq(decoded.paths, [@geometry.Path::open(points)])
  assert_eq(@geometry.encode_decoded(decoded), words)
}

///|
test "multipart line command stream round trips" {
  let lines = [
    [@model.Point::new(1, 2), @model.Point::new(3, 4), @model.Point::new(5, 8)],
    [@model.Point::new(20, 30), @model.Point::new(18, 40)],
  ]
  let words = @geometry.encode_lines(lines)
  let decoded = @geometry.decode_geometry(@model.GeomType::LineString, words)
  assert_eq(decoded.paths, [
    @geometry.Path::open(lines[0]),
    @geometry.Path::open(lines[1]),
  ])
  assert_eq(@geometry.encode_decoded(decoded), words)
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
  let words = @geometry.encode_polygons(rings)
  let decoded = @geometry.decode_geometry(@model.GeomType::Polygon, words)
  assert_eq(decoded.paths, [
    @geometry.Path::closed(rings[0]),
    @geometry.Path::closed(rings[1]),
  ])
  assert_eq(@geometry.encode_decoded(decoded), words)
  @geometry.validate_polygon_rings(decoded)
}

///|
test "unknown geometry accepts only an empty stream" {
  assert_eq(@geometry.decode_geometry(@model.GeomType::Unknown, []), {
    geometry_type: @model.GeomType::Unknown,
    paths: [],
  })
  let mut rejected = false
  ignore(@geometry.decode_geometry(@model.GeomType::Unknown, [9U, 0U, 0U])) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "geometry grammar rejects misplaced commands" {
  let invalid : Array[(@model.GeomType, Array[UInt32])] = [
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
    ignore(@geometry.decode_geometry(kind, words)) catch {
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
    ignore(@geometry.decode_geometry(@model.GeomType::Point, words)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "geometry decoder rejects coordinate accumulation overflow" {
  let words = [
    @geometry.command_header(@geometry.CommandId::MoveTo, 2),
    @wire.zigzag_encode_i32(2147483647),
    0U,
    @wire.zigzag_encode_i32(1),
    0U,
  ]
  let mut rejected = false
  ignore(@geometry.decode_geometry(@model.GeomType::Point, words)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "ring analysis follows screen-coordinate winding" {
  let clockwise = @geometry.Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(10, 0),
    @model.Point::new(10, 10),
    @model.Point::new(0, 10),
  ])
  let counterclockwise = @geometry.Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(0, 10),
    @model.Point::new(10, 10),
    @model.Point::new(10, 0),
  ])
  assert_eq(@geometry.ring_winding(clockwise), @geometry.RingWinding::Clockwise)
  assert_eq(
    @geometry.ring_winding(counterclockwise),
    @geometry.RingWinding::CounterClockwise,
  )
  assert_eq(@geometry.signed_ring_area2(clockwise), 200.0)
  assert_eq(@geometry.signed_ring_area2(counterclockwise), -200.0)
}

///|
test "geometry analysis reports bounds duplicates and lengths" {
  let path = @geometry.Path::open([
    @model.Point::new(-2, 5),
    @model.Point::new(3, 5),
    @model.Point::new(3, 5),
    @model.Point::new(3, 9),
  ])
  let geometry : @geometry.DecodedGeometry = {
    geometry_type: @model.GeomType::LineString,
    paths: [path],
  }
  assert_eq(
    @geometry.geometry_bounds(geometry),
    Some({ min_x: -2, min_y: 5, max_x: 3, max_y: 9, }),
  )
  assert_eq(@geometry.path_duplicate_step_count(path), 1)
  assert_eq(@geometry.path_distinct_point_count(path), 3)
  assert_eq(@geometry.path_manhattan_length(path), 9L)
}

///|
test "polygon ring validator rejects hole before exterior and zero area" {
  let hole = @geometry.Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(0, 10),
    @model.Point::new(10, 10),
    @model.Point::new(10, 0),
  ])
  let flat = @geometry.Path::closed([
    @model.Point::new(0, 0),
    @model.Point::new(1, 0),
    @model.Point::new(2, 0),
  ])
  for ring in [hole, flat] {
    let geometry : @geometry.DecodedGeometry = {
      geometry_type: @model.GeomType::Polygon,
      paths: [ring],
    }
    let mut rejected = false
    @geometry.validate_polygon_rings(geometry) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
