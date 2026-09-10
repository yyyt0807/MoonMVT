///|
pub(all) enum RingWinding {
  Clockwise
  CounterClockwise
  Degenerate
} derive(Debug, Eq)

///|
pub fn RingWinding::name(self : RingWinding) -> String {
  match self {
    Clockwise => "clockwise"
    CounterClockwise => "counterclockwise"
    Degenerate => "degenerate"
  }
}

///|
pub(all) struct RingInfo {
  index : Int
  winding : RingWinding
  signed_area2 : Double
  bounds : @model.Bounds
  point_count : Int
  distinct_points : Int
} derive(Debug, Eq)

///|
pub fn geometry_bounds(geometry : DecodedGeometry) -> @model.Bounds? {
  let mut bounds : @model.Bounds? = None
  for path in geometry.paths {
    for point in path.points {
      bounds = match bounds {
        None => Some(@model.Bounds::from_point(point))
        Some(current) => Some(current.include_point(point))
      }
    }
  }
  bounds
}

///|
/// Twice the signed shoelace area in tile coordinates. Because MVT's y axis is
/// downward, positive values are clockwise on screen.
pub fn signed_ring_area2(path : Path) -> Double {
  if path.points.length() < 3 {
    return 0.0
  }
  let mut area = 0.0
  for index in 0..<path.points.length() {
    let current = path.points[index]
    let next = path.points[(index + 1) % path.points.length()]
    area += current.x.to_double() * next.y.to_double() -
      next.x.to_double() * current.y.to_double()
  }
  area
}

///|
pub fn ring_winding(path : Path) -> RingWinding {
  let area = signed_ring_area2(path)
  if area > 0.0 {
    Clockwise
  } else if area < 0.0 {
    CounterClockwise
  } else {
    Degenerate
  }
}

///|
pub fn path_distinct_point_count(path : Path) -> Int {
  let mut count = 0
  for index, point in path.points {
    let mut seen = false
    for earlier in 0..<index {
      if point == path.points[earlier] {
        seen = true
        break
      }
    }
    if !seen {
      count += 1
    }
  }
  count
}

///|
pub fn path_duplicate_step_count(path : Path) -> Int {
  let mut count = 0
  for index in 1..<path.points.length() {
    if path.points[index] == path.points[index - 1] {
      count += 1
    }
  }
  count
}

///|
pub fn path_manhattan_length(path : Path) -> Int64 {
  let mut total = 0L
  for index in 1..<path.points.length() {
    total += path.points[index - 1].manhattan_distance(path.points[index])
  }
  if path.closed && path.points.length() > 1 {
    total += path.points[path.points.length() - 1].manhattan_distance(path.points[0])
  }
  total
}

///|
pub fn polygon_ring_info(
  geometry : DecodedGeometry,
) -> Array[RingInfo] raise @error.MvtError {
  if geometry.geometry_type != @model.GeomType::Polygon {
    raise @error.MvtError::InvalidArgument(
      "ring analysis requires polygon geometry",
    )
  }
  let output : Array[RingInfo] = []
  for index, path in geometry.paths {
    if path.points.is_empty() {
      raise @error.MvtError::InvalidGeometry(
        path="geometry.ring[\{index}]",
        detail="ring is empty",
      )
    }
    output.push({
      index,
      winding: ring_winding(path),
      signed_area2: signed_ring_area2(path),
      bounds: geometry_bounds({
        geometry_type: @model.GeomType::Polygon,
        paths: [path],
      }).unwrap(),
      point_count: path.points.length(),
      distinct_points: path_distinct_point_count(path),
    })
  }
  output
}

///|
/// Validate MVT polygon ring ordering: an exterior clockwise ring starts each
/// polygon and counterclockwise rings following it are holes.
pub fn validate_polygon_rings(
  geometry : DecodedGeometry,
  path? : String = "geometry",
) -> Unit raise @error.MvtError {
  let infos = polygon_ring_info(geometry)
  let mut have_exterior = false
  for info in infos {
    if info.distinct_points < 3 || info.winding == RingWinding::Degenerate {
      raise @error.MvtError::InvalidGeometry(
        path="\{path}.ring[\{info.index}]",
        detail="ring must contain at least three distinct non-collinear points",
      )
    }
    match info.winding {
      Clockwise => have_exterior = true
      CounterClockwise =>
        if !have_exterior {
          raise @error.MvtError::InvalidGeometry(
            path="\{path}.ring[\{info.index}]",
            detail="interior ring appears before an exterior ring",
          )
        }
      Degenerate => ()
    }
  }
}

