///|
/// Expanded path decoded from an MVT geometry command stream.
#derive(Debug, Eq)
pub(all) struct Path {
  points : Array[@model.Point]
  closed : Bool
}

///|
pub fn Path::open(points : Array[@model.Point]) -> Path {
  { points, closed: false, }
}

///|
pub fn Path::closed(points : Array[@model.Point]) -> Path {
  { points, closed: true, }
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  self.points.is_empty()
}

///|
pub fn Path::first(self : Path) -> @model.Point? {
  if self.points.is_empty() {
    None
  } else {
    Some(self.points[0])
  }
}

///|
pub fn Path::last(self : Path) -> @model.Point? {
  if self.points.is_empty() {
    None
  } else {
    Some(self.points[self.points.length() - 1])
  }
}

///|
#derive(Debug, Eq)
pub(all) struct DecodedGeometry {
  geometry_type : @model.GeomType
  paths : Array[Path]
}

///|
pub fn DecodedGeometry::point_count(self : DecodedGeometry) -> Int32 {
  let mut count = 0
  for path in self.paths {
    count += path.points.length()
  }
  count
}

///|
pub fn DecodedGeometry::path_count(self : DecodedGeometry) -> Int32 {
  self.paths.length()
}

///|
#derive(Debug, Eq)
pub(all) enum CommandId {
  MoveTo
  LineTo
  ClosePath
}

///|
pub fn CommandId::number(self : CommandId) -> UInt32 {
  match self {
    MoveTo => 1U
    LineTo => 2U
    ClosePath => 7U
  }
}

///|
pub fn CommandId::name(self : CommandId) -> String {
  match self {
    MoveTo => "MoveTo"
    LineTo => "LineTo"
    ClosePath => "ClosePath"
  }
}

///|
pub fn CommandId::from_number(
  value : UInt32,
  path : String,
) -> CommandId raise @error.MvtError {
  match value {
    1U => MoveTo
    2U => LineTo
    7U => ClosePath
    _ =>
      raise @error.MvtError::InvalidGeometry(
        path~,
        detail="unknown command id \{value}",
      )
  }
}

///|
#derive(Debug, Eq)
pub(all) struct CommandHeader {
  command : CommandId
  count : Int32
}

///|
pub fn command_header(
  command : CommandId,
  count : Int32,
) -> UInt32 raise @error.MvtError {
  if count <= 0 || count > 0x1fffffff {
    raise @error.MvtError::InvalidArgument(
      "geometry command count must be in 1..536870911",
    )
  }
  (count.reinterpret_as_uint() << 3) | command.number()
}

///|
pub fn parse_command_header(
  word : UInt32,
  path : String,
) -> CommandHeader raise @error.MvtError {
  let count = (word >> 3).reinterpret_as_int()
  if count == 0 {
    raise @error.MvtError::InvalidGeometry(
      path~,
      detail="command count must not be zero",
    )
  }
  { command: CommandId::from_number(word & 7U, path), count, }
}

///|
pub extend CommandHeader with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CommandHeader with Eq::{not_equal, equal}

///|
pub extend CommandId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CommandId with Eq::{not_equal, equal}

///|
pub extend DecodedGeometry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DecodedGeometry with Eq::{not_equal, equal}

///|
pub extend Path with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Path with Eq::{not_equal, equal}
