///|
/// Geometry type values from the MVT schema.
#derive(Debug, Eq)
pub(all) enum GeomType {
  Unknown
  Point
  LineString
  Polygon
}

///|
pub fn GeomType::number(self : GeomType) -> Int32 {
  match self {
    Unknown => 0
    Point => 1
    LineString => 2
    Polygon => 3
  }
}

///|
pub fn GeomType::name(self : GeomType) -> String {
  match self {
    Unknown => "unknown"
    Point => "point"
    LineString => "linestring"
    Polygon => "polygon"
  }
}

///|
pub fn GeomType::from_number(
  value : Int32,
  path : String,
) -> GeomType raise @error.MvtError {
  match value {
    0 => Unknown
    1 => Point
    2 => LineString
    3 => Polygon
    _ =>
      raise @error.MvtError::InvalidTile(
        path~,
        detail="geometry type must be in 0..3",
      )
  }
}

///|
/// Tile-local integer coordinate. The y axis follows the MVT tile coordinate
/// convention and typically increases downward.
#derive(Debug, Eq)
pub(all) struct Point {
  x : Int32
  y : Int32
}

///|
pub fn Point::new(x : Int32, y : Int32) -> Point {
  { x, y, }
}

///|
pub fn Point::translate(self : Point, dx : Int32, dy : Int32) -> Point {
  { x: self.x + dx, y: self.y + dy, }
}

///|
pub fn Point::manhattan_distance(self : Point, other : Point) -> Int64 {
  abs64(self.x.to_int64() - other.x.to_int64()) +
  abs64(self.y.to_int64() - other.y.to_int64())
}

///|
#derive(Debug, Eq)
pub(all) struct Bounds {
  min_x : Int32
  min_y : Int32
  max_x : Int32
  max_y : Int32
}

///|
pub fn Bounds::from_point(point : Point) -> Bounds {
  { min_x: point.x, min_y: point.y, max_x: point.x, max_y: point.y, }
}

///|
pub fn Bounds::include_point(self : Bounds, point : Point) -> Bounds {
  {
    min_x: if point.x < self.min_x {
      point.x
    } else {
      self.min_x
    },
    min_y: if point.y < self.min_y {
      point.y
    } else {
      self.min_y
    },
    max_x: if point.x > self.max_x {
      point.x
    } else {
      self.max_x
    },
    max_y: if point.y > self.max_y {
      point.y
    } else {
      self.max_y
    },
  }
}

///|
pub fn Bounds::width(self : Bounds) -> Int64 {
  self.max_x.to_int64() - self.min_x.to_int64()
}

///|
pub fn Bounds::height(self : Bounds) -> Int64 {
  self.max_y.to_int64() - self.min_y.to_int64()
}

///|
pub fn Bounds::contains(self : Bounds, point : Point) -> Bool {
  point.x >= self.min_x &&
  point.x <= self.max_x &&
  point.y >= self.min_y &&
  point.y <= self.max_y
}

///|
/// Resolved user-facing property. The encoded dictionary indexes are absent.
#derive(Debug, Eq)
pub(all) struct Property {
  key : String
  value : MvtValue
}

///|
/// MVT feature model. Tags contain alternating key and value dictionary indexes.
#derive(Debug, Eq)
pub(all) struct Feature {
  id : UInt64?
  tags : Array[Int32]
  geometry_type : GeomType
  geometry : Array[UInt32]
}

///|
pub fn Feature::empty(geometry_type : GeomType) -> Feature {
  { id: None, tags: [], geometry_type, geometry: [], }
}

///|
pub fn Feature::with_id(self : Feature, id : UInt64) -> Feature {
  { ..self, id: Some(id), }
}

///|
pub fn Feature::without_id(self : Feature) -> Feature {
  { ..self, id: None, }
}

///|
pub fn Feature::property_count(self : Feature) -> Int32 {
  self.tags.length() / 2
}

///|
/// MVT layer model. Dictionary order and feature order are observable.
#derive(Debug, Eq)
pub(all) struct Layer {
  name : String
  features : Array[Feature]
  keys : Array[String]
  values : Array[MvtValue]
  extent : Int32
  version : Int32
}

///|
pub fn Layer::empty(name : String, extent~ : Int32 = 4096) -> Layer {
  { name, features: [], keys: [], values: [], extent, version: 2, }
}

///|
pub fn Layer::feature_count(self : Layer) -> Int32 {
  self.features.length()
}

///|
pub fn Layer::property_dictionary_size(self : Layer) -> Int32 {
  self.keys.length() + self.values.length()
}

///|
#derive(Debug, Eq)
pub(all) struct Tile {
  layers : Array[Layer]
}

///|
pub fn Tile::empty() -> Tile {
  { layers: [], }
}

///|
pub fn Tile::layer_count(self : Tile) -> Int32 {
  self.layers.length()
}

///|
#derive(Debug, Eq)
pub(all) struct TileSummary {
  layers : Int32
  features : Int32
  points : Int32
  lines : Int32
  polygons : Int32
  unknown_geometries : Int32
  geometry_words : Int32
}

///|
fn abs64(value : Int64) -> Int64 {
  if value < 0L {
    -value
  } else {
    value
  }
}

///|
pub extend Bounds with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Bounds with Eq::{not_equal, equal}

///|
pub extend Feature with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Feature with Eq::{not_equal, equal}

///|
pub extend GeomType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GeomType with Eq::{not_equal, equal}

///|
pub extend Layer with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Layer with Eq::{not_equal, equal}

///|
pub extend Point with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Point with Eq::{not_equal, equal}

///|
pub extend Property with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Property with Eq::{not_equal, equal}

///|
pub extend Tile with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Tile with Eq::{not_equal, equal}

///|
pub extend TileSummary with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TileSummary with Eq::{not_equal, equal}
