///|
pub fn Tile::layer_by_name(self : Tile, name : String) -> Layer? {
  for layer in self.layers {
    if layer.name == name {
      return Some(layer)
    }
  }
  None
}

///|
pub fn Layer::feature_by_id(self : Layer, id : UInt64) -> Feature? {
  for feature in self.features {
    if feature.id == Some(id) {
      return Some(feature)
    }
  }
  None
}

///|
/// Resolve raw tag indexes into user-facing properties.
pub fn Layer::resolve_properties(
  self : Layer,
  feature : Feature,
  feature_path? : String = "feature",
) -> Array[Property] raise @error.MvtError {
  if feature.tags.length() % 2 != 0 {
    raise @error.MvtError::InvalidTile(
      path=feature_path + ".tags",
      detail="tag array must contain key/value index pairs",
    )
  }
  let properties : Array[Property] = []
  let mut index = 0
  while index < feature.tags.length() {
    let key_index = feature.tags[index]
    let value_index = feature.tags[index + 1]
    if key_index < 0 || key_index >= self.keys.length() {
      raise @error.MvtError::InvalidTile(
        path=feature_path + ".tags[\{index}]",
        detail="key index \{key_index} is outside dictionary",
      )
    }
    if value_index < 0 || value_index >= self.values.length() {
      raise @error.MvtError::InvalidTile(
        path=feature_path + ".tags[\{index + 1}]",
        detail="value index \{value_index} is outside dictionary",
      )
    }
    properties.push({ key: self.keys[key_index], value: self.values[value_index] })
    index += 2
  }
  properties
}

///|
pub fn Layer::property(
  self : Layer,
  feature : Feature,
  key : String,
) -> MvtValue? raise @error.MvtError {
  for property in self.resolve_properties(feature) {
    if property.key == key {
      return Some(property.value)
    }
  }
  None
}

///|
pub fn Tile::summary(self : Tile) -> TileSummary {
  let mut features = 0
  let mut points = 0
  let mut lines = 0
  let mut polygons = 0
  let mut unknown_geometries = 0
  let mut geometry_words = 0
  for layer in self.layers {
    features += layer.features.length()
    for feature in layer.features {
      geometry_words += feature.geometry.length()
      match feature.geometry_type {
        Point => points += 1
        LineString => lines += 1
        Polygon => polygons += 1
        Unknown => unknown_geometries += 1
      }
    }
  }
  {
    layers: self.layers.length(),
    features,
    points,
    lines,
    polygons,
    unknown_geometries,
    geometry_words,
  }
}

///|
/// Copy a tile retaining only layers accepted by the predicate.
pub fn Tile::filter_layers(self : Tile, predicate : (Layer) -> Bool) -> Tile {
  let layers : Array[Layer] = []
  for layer in self.layers {
    if predicate(layer) {
      layers.push(layer)
    }
  }
  { layers, }
}

///|
/// Copy a layer retaining only features accepted by the predicate. Dictionaries
/// are deliberately preserved; use a builder to compact them.
pub fn Layer::filter_features(
  self : Layer,
  predicate : (Feature) -> Bool,
) -> Layer {
  let features : Array[Feature] = []
  for feature in self.features {
    if predicate(feature) {
      features.push(feature)
    }
  }
  { ..self, features }
}
