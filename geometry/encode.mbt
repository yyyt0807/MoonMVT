///|
/// Encode a single- or multi-point geometry.
pub fn encode_points(
  points : ArrayView[@model.Point],
) -> Array[UInt] raise @error.MvtError {
  if points.is_empty() {
    raise @error.MvtError::InvalidArgument(
      "point geometry requires at least one point",
    )
  }
  let output : Array[UInt] = [
    command_header(CommandId::MoveTo, points.length()),
  ]
  let cursor : Cursor = { x: 0L, y: 0L, }
  for point in points {
    append_point(output, cursor, point, "point")
  }
  output
}

///|
/// Encode one or more lines. Every line must contain at least two points.
pub fn encode_lines(
  lines : ArrayView[Array[@model.Point]],
) -> Array[UInt] raise @error.MvtError {
  if lines.is_empty() {
    raise @error.MvtError::InvalidArgument(
      "line geometry requires at least one line",
    )
  }
  let output : Array[UInt] = []
  let cursor : Cursor = { x: 0L, y: 0L, }
  for index, line in lines {
    if line.length() < 2 {
      raise @error.MvtError::InvalidArgument(
        "line[\{index}] requires at least two points",
      )
    }
    output.push(command_header(CommandId::MoveTo, 1))
    append_point(output, cursor, line[0], "line[\{index}].points[0]")
    output.push(command_header(CommandId::LineTo, line.length() - 1))
    for point_index in 1..<line.length() {
      append_point(
        output,
        cursor,
        line[point_index],
        "line[\{index}].points[\{point_index}]",
      )
    }
  }
  output
}

///|
/// Encode polygon rings. Callers provide open rings: the first coordinate must
/// not be repeated at the end because ClosePath carries closure semantics.
pub fn encode_polygons(
  rings : ArrayView[Array[@model.Point]],
) -> Array[UInt] raise @error.MvtError {
  if rings.is_empty() {
    raise @error.MvtError::InvalidArgument(
      "polygon geometry requires at least one ring",
    )
  }
  let output : Array[UInt] = []
  let cursor : Cursor = { x: 0L, y: 0L, }
  for index, ring in rings {
    validate_open_ring_input(ring, index)
    output.push(command_header(CommandId::MoveTo, 1))
    append_point(output, cursor, ring[0], "ring[\{index}].points[0]")
    output.push(command_header(CommandId::LineTo, ring.length() - 1))
    for point_index in 1..<ring.length() {
      append_point(
        output,
        cursor,
        ring[point_index],
        "ring[\{index}].points[\{point_index}]",
      )
    }
    output.push(command_header(CommandId::ClosePath, 1))
  }
  output
}

///|
/// Re-encode an expanded geometry using its declared geometry type.
pub fn encode_decoded(
  geometry : DecodedGeometry,
) -> Array[UInt] raise @error.MvtError {
  let points : Array[@model.Point] = []
  let paths : Array[Array[@model.Point]] = []
  match geometry.geometry_type {
    Unknown => {
      if !geometry.paths.is_empty() {
        raise @error.MvtError::InvalidArgument(
          "unknown geometry must not contain paths",
        )
      }
      []
    }
    Point => {
      for path in geometry.paths {
        if path.closed {
          raise @error.MvtError::InvalidArgument("point path must be open")
        }
        for point in path.points {
          points.push(point)
        }
      }
      encode_points(points)
    }
    LineString => {
      for path in geometry.paths {
        if path.closed {
          raise @error.MvtError::InvalidArgument("line path must be open")
        }
        paths.push(path.points)
      }
      encode_lines(paths)
    }
    Polygon => {
      for path in geometry.paths {
        if !path.closed {
          raise @error.MvtError::InvalidArgument("polygon ring must be closed")
        }
        paths.push(path.points)
      }
      encode_polygons(paths)
    }
  }
}

///|
priv struct Cursor {
  mut x : Int64
  mut y : Int64
}

///|
fn append_point(
  output : Array[UInt],
  cursor : Cursor,
  point : @model.Point,
  path : String,
) -> Unit raise @error.MvtError {
  let target_x = point.x.to_int64()
  let target_y = point.y.to_int64()
  let dx = target_x - cursor.x
  let dy = target_y - cursor.y
  check_delta(dx, path + ".x")
  check_delta(dy, path + ".y")
  output.push(@wire.zigzag_encode_i32(dx.to_int()))
  output.push(@wire.zigzag_encode_i32(dy.to_int()))
  cursor.x = target_x
  cursor.y = target_y
}

///|
fn check_delta(value : Int64, path : String) -> Unit raise @error.MvtError {
  if value < -2147483648L || value > 2147483647L {
    raise @error.MvtError::NumericOverflow(path~)
  }
}

///|
fn validate_open_ring_input(
  ring : Array[@model.Point],
  index : Int,
) -> Unit raise @error.MvtError {
  if ring.length() < 3 {
    raise @error.MvtError::InvalidArgument(
      "ring[\{index}] requires at least three points",
    )
  }
  if ring[0] == ring[ring.length() - 1] {
    raise @error.MvtError::InvalidArgument(
      "ring[\{index}] must be open; remove the duplicate closing point",
    )
  }
  let mut distinct = 1
  for point_index in 1..<ring.length() {
    let mut seen = false
    for earlier in 0..<point_index {
      if ring[point_index] == ring[earlier] {
        seen = true
        break
      }
    }
    if !seen {
      distinct += 1
    }
  }
  if distinct < 3 {
    raise @error.MvtError::InvalidArgument(
      "ring[\{index}] requires at least three distinct points",
    )
  }
}
