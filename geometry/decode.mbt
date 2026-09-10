///|
/// Expand an MVT command stream into typed paths while validating the command
/// grammar for the declared geometry type.
pub fn decode_geometry(
  geometry_type : @model.GeomType,
  words : ArrayView[UInt],
  path? : String = "geometry",
) -> DecodedGeometry raise @error.MvtError {
  match geometry_type {
    Unknown => {
      if !words.is_empty() {
        raise @error.MvtError::InvalidGeometry(
          path=path,
          detail="unknown geometry must have an empty command stream",
        )
      }
      { geometry_type, paths: [] }
    }
    Point => decode_point_geometry(words, path)
    LineString => decode_line_geometry(words, path)
    Polygon => decode_polygon_geometry(words, path)
  }
}

///|
pub fn validate_geometry(
  geometry_type : @model.GeomType,
  words : ArrayView[UInt],
  path? : String = "geometry",
) -> Unit raise @error.MvtError {
  ignore(decode_geometry(geometry_type, words, path~))
}

///|
fn decode_point_geometry(
  words : ArrayView[UInt],
  path : String,
) -> DecodedGeometry raise @error.MvtError {
  if words.is_empty() {
    raise @error.MvtError::InvalidGeometry(
      path=path,
      detail="point command stream is empty",
    )
  }
  let header = parse_command_header(words[0], path + "[0]")
  if header.command != CommandId::MoveTo {
    raise unexpected_command(path, 0, "MoveTo", header.command)
  }
  let required = checked_parameter_end(1, header.count, path)
  if required != words.length() {
    raise @error.MvtError::InvalidGeometry(
      path=path,
      detail="point geometry must contain exactly one MoveTo command",
    )
  }
  let cursor : DecodeCursor = { x: 0L, y: 0L }
  let points : Array[@model.Point] = []
  let mut index = 1
  for point_index in 0..<header.count {
    let (point, next) = decode_point(words, index, cursor, "\{path}.point[\{point_index}]")
    points.push(point)
    index = next
  }
  { geometry_type: @model.GeomType::Point, paths: [Path::open(points)] }
}

///|
fn decode_line_geometry(
  words : ArrayView[UInt],
  path : String,
) -> DecodedGeometry raise @error.MvtError {
  if words.is_empty() {
    raise @error.MvtError::InvalidGeometry(
      path=path,
      detail="line command stream is empty",
    )
  }
  let cursor : DecodeCursor = { x: 0L, y: 0L }
  let paths : Array[Path] = []
  let mut index = 0
  let mut part = 0
  while index < words.length() {
    let move_header = parse_command_header(words[index], "\{path}[\{index}]")
    if move_header.command != CommandId::MoveTo || move_header.count != 1 {
      raise @error.MvtError::InvalidGeometry(
        path="\{path}[\{index}]",
        detail="line part must start with MoveTo count 1",
      )
    }
    index += 1
    let (first, after_first) = decode_point(
      words,
      index,
      cursor,
      "\{path}.part[\{part}].point[0]",
    )
    index = after_first
    if index >= words.length() {
      raise @error.MvtError::InvalidGeometry(
        path=path,
        detail="line part is missing LineTo",
      )
    }
    let line_header = parse_command_header(words[index], "\{path}[\{index}]")
    if line_header.command != CommandId::LineTo {
      raise unexpected_command(path, index, "LineTo", line_header.command)
    }
    index += 1
    ignore(checked_parameter_end(index, line_header.count, path))
    let points : Array[@model.Point] = [first]
    for point_index in 0..<line_header.count {
      let (point, next) = decode_point(
        words,
        index,
        cursor,
        "\{path}.part[\{part}].point[\{point_index + 1}]",
      )
      points.push(point)
      index = next
    }
    paths.push(Path::open(points))
    part += 1
  }
  { geometry_type: @model.GeomType::LineString, paths }
}

///|
fn decode_polygon_geometry(
  words : ArrayView[UInt],
  path : String,
) -> DecodedGeometry raise @error.MvtError {
  if words.is_empty() {
    raise @error.MvtError::InvalidGeometry(
      path=path,
      detail="polygon command stream is empty",
    )
  }
  let cursor : DecodeCursor = { x: 0L, y: 0L }
  let paths : Array[Path] = []
  let mut index = 0
  let mut ring = 0
  while index < words.length() {
    let move_header = parse_command_header(words[index], "\{path}[\{index}]")
    if move_header.command != CommandId::MoveTo || move_header.count != 1 {
      raise @error.MvtError::InvalidGeometry(
        path="\{path}[\{index}]",
        detail="polygon ring must start with MoveTo count 1",
      )
    }
    index += 1
    let (first, after_first) = decode_point(
      words,
      index,
      cursor,
      "\{path}.ring[\{ring}].point[0]",
    )
    index = after_first
    if index >= words.length() {
      raise @error.MvtError::InvalidGeometry(
        path=path,
        detail="polygon ring is missing LineTo",
      )
    }
    let line_header = parse_command_header(words[index], "\{path}[\{index}]")
    if line_header.command != CommandId::LineTo || line_header.count < 2 {
      raise @error.MvtError::InvalidGeometry(
        path="\{path}[\{index}]",
        detail="polygon ring requires LineTo count of at least 2",
      )
    }
    index += 1
    ignore(checked_parameter_end(index, line_header.count, path))
    let points : Array[@model.Point] = [first]
    for point_index in 0..<line_header.count {
      let (point, next) = decode_point(
        words,
        index,
        cursor,
        "\{path}.ring[\{ring}].point[\{point_index + 1}]",
      )
      points.push(point)
      index = next
    }
    if index >= words.length() {
      raise @error.MvtError::InvalidGeometry(
        path=path,
        detail="polygon ring is missing ClosePath",
      )
    }
    let close_header = parse_command_header(words[index], "\{path}[\{index}]")
    if close_header.command != CommandId::ClosePath || close_header.count != 1 {
      raise @error.MvtError::InvalidGeometry(
        path="\{path}[\{index}]",
        detail="polygon ring must end with ClosePath count 1",
      )
    }
    index += 1
    paths.push(Path::closed(points))
    ring += 1
  }
  { geometry_type: @model.GeomType::Polygon, paths }
}

///|
priv struct DecodeCursor {
  mut x : Int64
  mut y : Int64
}

///|
fn decode_point(
  words : ArrayView[UInt],
  index : Int,
  cursor : DecodeCursor,
  path : String,
) -> (@model.Point, Int) raise @error.MvtError {
  if index < 0 || index + 1 >= words.length() {
    raise @error.MvtError::InvalidGeometry(
      path=path,
      detail="coordinate pair is truncated",
    )
  }
  let dx = @wire.zigzag_decode_i32(words[index]).to_int64()
  let dy = @wire.zigzag_decode_i32(words[index + 1]).to_int64()
  let x = cursor.x + dx
  let y = cursor.y + dy
  if x < -2147483648L || x > 2147483647L {
    raise @error.MvtError::NumericOverflow(path=path + ".x")
  }
  if y < -2147483648L || y > 2147483647L {
    raise @error.MvtError::NumericOverflow(path=path + ".y")
  }
  cursor.x = x
  cursor.y = y
  (@model.Point::new(x.to_int(), y.to_int()), index + 2)
}

///|
fn checked_parameter_end(
  start : Int,
  point_count : Int,
  path : String,
) -> Int raise @error.MvtError {
  if point_count > (2147483647 - start) / 2 {
    raise @error.MvtError::ResourceLimit(
      limit=path + ".parameters",
      actual=point_count.to_int64() * 2L,
      maximum=2147483647L,
    )
  }
  start + point_count * 2
}

///|
fn unexpected_command(
  path : String,
  index : Int,
  expected : String,
  actual : CommandId,
) -> @error.MvtError {
  @error.MvtError::InvalidGeometry(
    path="\{path}[\{index}]",
    detail="expected \{expected}, got \{actual.name()}",
  )
}

