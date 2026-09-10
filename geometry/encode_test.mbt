///|
test "command headers match MVT examples" {
  assert_eq(command_header(CommandId::MoveTo, 1), 9U)
  assert_eq(command_header(CommandId::LineTo, 2), 18U)
  assert_eq(command_header(CommandId::ClosePath, 1), 15U)
  assert_eq(parse_command_header(18U, "geometry"), { command: CommandId::LineTo, count: 2 })
}

///|
test "point encoding delta-compresses one cursor" {
  assert_eq(
    encode_points([@model.Point::new(25, 17)]),
    [9U, 50U, 34U],
  )
  assert_eq(
    encode_points([
      @model.Point::new(25, 17),
      @model.Point::new(30, 10),
    ]),
    [17U, 50U, 34U, 10U, 13U],
  )
}

///|
test "line encoding carries cursor across parts" {
  let encoded = encode_lines([
    [@model.Point::new(2, 2), @model.Point::new(5, 7)],
    [@model.Point::new(10, 10), @model.Point::new(8, 9)],
  ])
  assert_eq(encoded, [9U, 4U, 4U, 10U, 6U, 10U, 9U, 10U, 6U, 10U, 3U, 1U])
}

///|
test "polygon encoding adds ClosePath without duplicate coordinate" {
  let ring = [
    @model.Point::new(3, 6),
    @model.Point::new(8, 6),
    @model.Point::new(8, 11),
    @model.Point::new(3, 11),
  ]
  assert_eq(
    encode_polygons([ring]),
    [9U, 6U, 12U, 26U, 10U, 0U, 0U, 10U, 9U, 0U, 15U],
  )
}

///|
test "geometry encoders reject empty and undersized input" {
  let mut failures = 0
  ignore(encode_points([])) catch { _ => failures += 1 }
  ignore(encode_lines([])) catch { _ => failures += 1 }
  ignore(encode_lines([[@model.Point::new(0, 0)]])) catch { _ => failures += 1 }
  ignore(encode_polygons([])) catch { _ => failures += 1 }
  ignore(
    encode_polygons([
      [@model.Point::new(0, 0), @model.Point::new(1, 0)],
    ]),
  ) catch {
    _ => failures += 1
  }
  assert_eq(failures, 5)
}

///|
test "polygon input uses open ring convention" {
  let closed = [
    @model.Point::new(0, 0),
    @model.Point::new(10, 0),
    @model.Point::new(0, 10),
    @model.Point::new(0, 0),
  ]
  let mut rejected = false
  ignore(encode_polygons([closed])) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "polygon rejects three positions with fewer than three distinct points" {
  let degenerate = [
    @model.Point::new(0, 0),
    @model.Point::new(1, 0),
    @model.Point::new(1, 0),
  ]
  let mut rejected = false
  ignore(encode_polygons([degenerate])) catch { _ => rejected = true }
  assert_true(rejected)
}

///|
test "delta overflow is rejected before uint32 truncation" {
  let mut rejected = false
  ignore(
    encode_lines([
      [
        @model.Point::new(-2147483647 - 1, 0),
        @model.Point::new(2147483647, 0),
      ],
    ]),
  ) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "expanded geometry encoding enforces path closure by type" {
  let points : DecodedGeometry = {
    geometry_type: @model.GeomType::Point,
    paths: [Path::open([@model.Point::new(1, 1)])],
  }
  assert_eq(encode_decoded(points), [9U, 2U, 2U])
  let invalid : DecodedGeometry = {
    geometry_type: @model.GeomType::LineString,
    paths: [Path::closed([@model.Point::new(0, 0), @model.Point::new(1, 1)])],
  }
  let mut rejected = false
  ignore(encode_decoded(invalid)) catch { _ => rejected = true }
  assert_true(rejected)
}
