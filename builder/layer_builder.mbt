///|
/// Add one typed feature while interning its property keys and values.
pub fn LayerBuilder::add_feature(
  self : LayerBuilder,
  input : FeatureInput,
) -> Unit raise @error.MvtError {
  @geometry.validate_geometry(input.geometry_type, input.geometry)
  reject_duplicate_property_keys(input.properties)
  self.add_feature_interned(input)
}

///|
fn LayerBuilder::add_feature_interned(
  self : LayerBuilder,
  input : FeatureInput,
) -> Unit {
  let tags : Array[Int] = []
  for item in input.properties {
    tags.push(self.intern_key(item.key))
    tags.push(self.intern_value(item.value))
  }
  self.features.push({
    id: input.id,
    tags,
    geometry_type: input.geometry_type,
    geometry: input.geometry.copy(),
  })
}

///|
pub fn LayerBuilder::add_points(
  self : LayerBuilder,
  points : Array[@model.Point],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> Unit raise @error.MvtError {
  self.add_feature(FeatureInput::points(points, properties~, id~))
}

///|
pub fn LayerBuilder::add_lines(
  self : LayerBuilder,
  lines : Array[Array[@model.Point]],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> Unit raise @error.MvtError {
  self.add_feature(FeatureInput::lines(lines, properties~, id~))
}

///|
pub fn LayerBuilder::add_polygons(
  self : LayerBuilder,
  rings : Array[Array[@model.Point]],
  properties? : Array[@model.Property] = [],
  id? : UInt64? = None,
) -> Unit raise @error.MvtError {
  self.add_feature(FeatureInput::polygons(rings, properties~, id~))
}

///|
pub fn LayerBuilder::intern_key(self : LayerBuilder, key : String) -> Int {
  for index, existing in self.keys {
    if existing == key {
      return index
    }
  }
  self.keys.push(key)
  self.keys.length() - 1
}

///|
pub fn LayerBuilder::intern_value(
  self : LayerBuilder,
  value : @model.MvtValue,
) -> Int {
  for index, existing in self.values {
    if existing.dictionary_equal(value) {
      return index
    }
  }
  self.values.push(value)
  self.values.length() - 1
}

///|
fn reject_duplicate_property_keys(
  properties : ArrayView[@model.Property],
) -> Unit raise @error.MvtError {
  for index, current in properties {
    if current.key == "" {
      raise @error.MvtError::InvalidArgument("property key must not be empty")
    }
    for earlier in 0..<index {
      if properties[earlier].key == current.key {
        raise @error.MvtError::InvalidArgument(
          "feature contains duplicate property key: " + current.key,
        )
      }
    }
  }
}

///|
pub fn TileBuilder::add_layer(
  self : TileBuilder,
  layer : @model.Layer,
) -> Unit raise @error.MvtError {
  for existing in self.layers {
    if existing.name == layer.name {
      raise @error.MvtError::InvalidArgument(
        "tile contains duplicate layer name: " + layer.name,
      )
    }
  }
  self.layers.push(layer)
}

///|
pub fn TileBuilder::add_built_layer(
  self : TileBuilder,
  layer : LayerBuilder,
) -> Unit raise @error.MvtError {
  self.add_layer(layer.finish())
}

///|
/// Rebuild a decoded layer into compact dictionaries. Feature and property order
/// is preserved while unreferenced and duplicate dictionary entries disappear.
pub fn compact_layer(
  layer : @model.Layer,
) -> @model.Layer raise @error.MvtError {
  let builder = LayerBuilder::new(layer.name, extent=layer.extent)
  for index, feature in layer.features {
    let input : FeatureInput = {
      id: feature.id,
      properties: layer.resolve_properties(
        feature,
        feature_path="features[\{index}]",
      ),
      geometry_type: feature.geometry_type,
      geometry: feature.geometry,
    }
    builder.add_feature_interned(input)
  }
  builder.finish()
}

///|
pub fn compact_tile(tile : @model.Tile) -> @model.Tile raise @error.MvtError {
  let builder = TileBuilder::new()
  for layer in tile.layers {
    builder.add_layer(compact_layer(layer))
  }
  builder.finish()
}
