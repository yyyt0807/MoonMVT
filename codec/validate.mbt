///|
/// Validate a caller-created model before deterministic encoding.
pub fn validate_tile(tile : @model.Tile) -> Unit raise @error.MvtError {
  for layer_index, layer in tile.layers {
    let path = "layers[\{layer_index}]"
    validate_layer(layer, path~)
    for earlier in 0..<layer_index {
      if tile.layers[earlier].name == layer.name {
        raise @error.MvtError::InvalidTile(
          path=path + ".name",
          detail="duplicate layer name: " + layer.name,
        )
      }
    }
  }
}

///|
pub fn validate_layer(
  layer : @model.Layer,
  path? : String = "layer",
) -> Unit raise @error.MvtError {
  if layer.name == "" {
    raise @error.MvtError::InvalidTile(
      path=path + ".name",
      detail="layer name must not be empty",
    )
  }
  reject_nul(layer.name, path + ".name")
  if layer.version != 2 {
    raise @error.MvtError::Unsupported(
      path=path + ".version",
      detail="MoonMVT version 0.1 supports MVT layer version 2 only",
    )
  }
  if layer.extent <= 0 {
    raise @error.MvtError::InvalidTile(
      path=path + ".extent",
      detail="extent must be positive",
    )
  }
  for key_index, key in layer.keys {
    reject_nul(key, "\{path}.keys[\{key_index}]")
  }
  for feature_index, feature in layer.features {
    validate_feature(layer, feature, path="\{path}.features[\{feature_index}]")
  }
}

///|
pub fn validate_feature(
  layer : @model.Layer,
  feature : @model.Feature,
  path? : String = "feature",
) -> Unit raise @error.MvtError {
  if feature.tags.length() % 2 != 0 {
    raise @error.MvtError::InvalidTile(
      path=path + ".tags",
      detail="tag array must contain key/value index pairs",
    )
  }
  let mut tag_index = 0
  while tag_index < feature.tags.length() {
    let key_index = feature.tags[tag_index]
    let value_index = feature.tags[tag_index + 1]
    if key_index < 0 || key_index >= layer.keys.length() {
      raise @error.MvtError::InvalidTile(
        path="\{path}.tags[\{tag_index}]",
        detail="key index \{key_index} is outside dictionary",
      )
    }
    if value_index < 0 || value_index >= layer.values.length() {
      raise @error.MvtError::InvalidTile(
        path="\{path}.tags[\{tag_index + 1}]",
        detail="value index \{value_index} is outside dictionary",
      )
    }
    tag_index += 2
  }
  @geometry.validate_geometry(
    feature.geometry_type,
    feature.geometry,
    path=path + ".geometry",
  )
  if feature.geometry_type == @model.GeomType::Polygon {
    @geometry.validate_polygon_rings(
      @geometry.decode_geometry(
        feature.geometry_type,
        feature.geometry,
        path=path + ".geometry",
      ),
      path=path + ".geometry",
    )
  }
}

///|
fn reject_nul(value : String, path : String) -> Unit raise @error.MvtError {
  for character in value {
    if character == '\u0000' {
      raise @error.MvtError::InvalidTile(
        path~,
        detail="text must not contain NUL",
      )
    }
  }
}
