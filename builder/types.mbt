///|
/// User-facing feature description with resolved properties.
pub(all) struct FeatureInput {
  id : UInt64?
  properties : Array[@model.Property]
  geometry_type : @model.GeomType
  geometry : Array[UInt]
} derive(Debug, Eq)

///|
pub fn property(key : String, value : @model.MvtValue) -> @model.Property {
  { key, value, }
}

///|
pub fn FeatureInput::raw(
  geometry_type : @model.GeomType,
  geometry : Array[UInt],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> FeatureInput {
  { id, properties, geometry_type, geometry, }
}

///|
pub fn FeatureInput::points(
  points : Array[@model.Point],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> FeatureInput raise @error.MvtError {
  {
    id,
    properties,
    geometry_type: @model.GeomType::Point,
    geometry: @geometry.encode_points(points),
  }
}

///|
pub fn FeatureInput::lines(
  lines : Array[Array[@model.Point]],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> FeatureInput raise @error.MvtError {
  {
    id,
    properties,
    geometry_type: @model.GeomType::LineString,
    geometry: @geometry.encode_lines(lines),
  }
}

///|
pub fn FeatureInput::polygons(
  rings : Array[Array[@model.Point]],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> FeatureInput raise @error.MvtError {
  let geometry = @geometry.encode_polygons(rings)
  @geometry.validate_polygon_rings(
    @geometry.decode_geometry(@model.GeomType::Polygon, geometry),
  )
  { id, properties, geometry_type: @model.GeomType::Polygon, geometry, }
}

///|
/// Mutable layer assembly state. `finish` returns owned snapshots.
pub(all) struct LayerBuilder {
  name : String
  extent : Int
  mut features : Array[@model.Feature]
  mut keys : Array[String]
  mut values : Array[@model.MvtValue]
}

///|
pub fn LayerBuilder::new(
  name : String,
  extent? : Int = 4096,
) -> LayerBuilder raise @error.MvtError {
  if name == "" {
    raise @error.MvtError::InvalidArgument("layer name must not be empty")
  }
  if extent <= 0 {
    raise @error.MvtError::InvalidArgument("layer extent must be positive")
  }
  { name, extent, features: [], keys: [], values: [], }
}

///|
pub fn LayerBuilder::feature_count(self : LayerBuilder) -> Int {
  self.features.length()
}

///|
pub fn LayerBuilder::key_count(self : LayerBuilder) -> Int {
  self.keys.length()
}

///|
pub fn LayerBuilder::value_count(self : LayerBuilder) -> Int {
  self.values.length()
}

///|
pub fn LayerBuilder::finish(self : LayerBuilder) -> @model.Layer {
  {
    name: self.name,
    features: self.features.copy(),
    keys: self.keys.copy(),
    values: self.values.copy(),
    extent: self.extent,
    version: 2,
  }
}

///|
pub(all) struct TileBuilder {
  mut layers : Array[@model.Layer]
}

///|
pub fn TileBuilder::new() -> TileBuilder {
  { layers: [], }
}

///|
pub fn TileBuilder::layer_count(self : TileBuilder) -> Int {
  self.layers.length()
}

///|
pub fn TileBuilder::finish(self : TileBuilder) -> @model.Tile {
  { layers: self.layers.copy(), }
}
