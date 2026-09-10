///|
/// Resolved feature information supplied to query predicates.
pub(all) struct FeatureView {
  index : Int
  id : UInt64?
  geometry_type : @model.GeomType
  properties : Array[@model.Property]
  bounds : @model.Bounds?
  path_count : Int
  point_count : Int
} derive(Debug, Eq)

///|
pub fn inspect_feature(
  layer : @model.Layer,
  index : Int,
) -> FeatureView raise @error.MvtError {
  if index < 0 || index >= layer.features.length() {
    raise @error.MvtError::InvalidArgument("feature index is outside layer")
  }
  let feature = layer.features[index]
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
    path="features[\{index}].geometry",
  )
  {
    index,
    id: feature.id,
    geometry_type: feature.geometry_type,
    properties: layer.resolve_properties(
      feature,
      feature_path="features[\{index}]",
    ),
    bounds: @geometry.geometry_bounds(geometry),
    path_count: geometry.path_count(),
    point_count: geometry.point_count(),
  }
}

///|
pub fn FeatureView::property(
  self : FeatureView,
  key : String,
) -> @model.MvtValue? {
  for item in self.properties {
    if item.key == key {
      return Some(item.value)
    }
  }
  None
}

///|
pub fn FeatureView::has_property(self : FeatureView, key : String) -> Bool {
  self.property(key) is Some(_)
}

///|
pub fn FeatureView::property_equals(
  self : FeatureView,
  key : String,
  expected : @model.MvtValue,
) -> Bool {
  match self.property(key) {
    Some(actual) => actual.dictionary_equal(expected)
    None => false
  }
}

///|
pub fn FeatureView::intersects_bounds(
  self : FeatureView,
  query : @model.Bounds,
) -> Bool {
  match self.bounds {
    None => false
    Some(bounds) =>
      bounds.min_x <= query.max_x &&
      bounds.max_x >= query.min_x &&
      bounds.min_y <= query.max_y &&
      bounds.max_y >= query.min_y
  }
}

///|
/// Filter a layer through resolved views and rebuild compact dictionaries.
pub fn filter_layer(
  layer : @model.Layer,
  predicate : (FeatureView) -> Bool,
) -> @model.Layer raise @error.MvtError {
  let features : Array[@model.Feature] = []
  for index, feature in layer.features {
    if predicate(inspect_feature(layer, index)) {
      features.push(feature)
    }
  }
  @builder.compact_layer({ ..layer, features, })
}

///|
pub fn filter_geometry_type(
  layer : @model.Layer,
  geometry_type : @model.GeomType,
) -> @model.Layer raise @error.MvtError {
  filter_layer(layer, view => view.geometry_type == geometry_type)
}

///|
pub fn filter_has_property(
  layer : @model.Layer,
  key : String,
) -> @model.Layer raise @error.MvtError {
  filter_layer(layer, view => view.has_property(key))
}

///|
pub fn filter_property_equals(
  layer : @model.Layer,
  key : String,
  value : @model.MvtValue,
) -> @model.Layer raise @error.MvtError {
  filter_layer(layer, view => view.property_equals(key, value))
}

///|
pub fn filter_intersects(
  layer : @model.Layer,
  bounds : @model.Bounds,
) -> @model.Layer raise @error.MvtError {
  filter_layer(layer, view => view.intersects_bounds(bounds))
}

///|
pub fn map_tile_layers(
  tile : @model.Tile,
  transform : (@model.Layer) -> @model.Layer raise @error.MvtError,
) -> @model.Tile raise @error.MvtError {
  let layers : Array[@model.Layer] = []
  for layer in tile.layers {
    layers.push(transform(layer))
  }
  { layers, }
}

///|
pub(all) struct LayerStatistics {
  name : String
  extent : Int
  features : Int
  point_features : Int
  line_features : Int
  polygon_features : Int
  unknown_features : Int
  properties : Int
  geometry_words : Int
  decoded_points : Int
  dictionary_keys : Int
  dictionary_values : Int
} derive(Debug, Eq)

///|
pub fn layer_statistics(
  layer : @model.Layer,
) -> LayerStatistics raise @error.MvtError {
  let mut point_features = 0
  let mut line_features = 0
  let mut polygon_features = 0
  let mut unknown_features = 0
  let mut properties = 0
  let mut geometry_words = 0
  let mut decoded_points = 0
  for index, feature in layer.features {
    match feature.geometry_type {
      Point => point_features += 1
      LineString => line_features += 1
      Polygon => polygon_features += 1
      Unknown => unknown_features += 1
    }
    properties += feature.property_count()
    geometry_words += feature.geometry.length()
    decoded_points += inspect_feature(layer, index).point_count
  }
  {
    name: layer.name,
    extent: layer.extent,
    features: layer.features.length(),
    point_features,
    line_features,
    polygon_features,
    unknown_features,
    properties,
    geometry_words,
    decoded_points,
    dictionary_keys: layer.keys.length(),
    dictionary_values: layer.values.length(),
  }
}

///|
pub(all) struct TileStatistics {
  layers : Int
  features : Int
  properties : Int
  geometry_words : Int
  decoded_points : Int
  layer_statistics : Array[LayerStatistics]
} derive(Debug, Eq)

///|
pub fn tile_statistics(
  tile : @model.Tile,
) -> TileStatistics raise @error.MvtError {
  let statistics : Array[LayerStatistics] = []
  let mut features = 0
  let mut properties = 0
  let mut geometry_words = 0
  let mut decoded_points = 0
  for layer in tile.layers {
    let item = layer_statistics(layer)
    features += item.features
    properties += item.properties
    geometry_words += item.geometry_words
    decoded_points += item.decoded_points
    statistics.push(item)
  }
  {
    layers: tile.layers.length(),
    features,
    properties,
    geometry_words,
    decoded_points,
    layer_statistics: statistics,
  }
}
