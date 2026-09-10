///|
/// Explicit resource ceilings for untrusted MVT input.
pub(all) struct DecodeLimits {
  max_tile_bytes : Int
  max_layers : Int
  max_features_per_layer : Int
  max_keys_per_layer : Int
  max_values_per_layer : Int
  max_tags_per_feature : Int
  max_geometry_words_per_feature : Int
  max_string_bytes : Int
  max_submessage_bytes : Int
  max_unknown_fields : Int
} derive(Debug, Eq)

///|
/// Conservative defaults suitable for network-delivered vector tiles.
pub fn DecodeLimits::standard() -> DecodeLimits {
  {
    max_tile_bytes: 16 * 1024 * 1024,
    max_layers: 256,
    max_features_per_layer: 100000,
    max_keys_per_layer: 65536,
    max_values_per_layer: 65536,
    max_tags_per_feature: 131072,
    max_geometry_words_per_feature: 4 * 1024 * 1024,
    max_string_bytes: 1024 * 1024,
    max_submessage_bytes: 8 * 1024 * 1024,
    max_unknown_fields: 100000,
  }
}

///|
/// Smaller limits for fuzzing, unit tests, and constrained browser workers.
pub fn DecodeLimits::constrained() -> DecodeLimits {
  {
    max_tile_bytes: 1024 * 1024,
    max_layers: 32,
    max_features_per_layer: 10000,
    max_keys_per_layer: 4096,
    max_values_per_layer: 4096,
    max_tags_per_feature: 8192,
    max_geometry_words_per_feature: 262144,
    max_string_bytes: 262144,
    max_submessage_bytes: 524288,
    max_unknown_fields: 4096,
  }
}

///|
/// Ensure all ceilings are positive and internally consistent.
pub fn DecodeLimits::validate(
  self : DecodeLimits,
) -> Unit raise @error.MvtError {
  check_positive("max_tile_bytes", self.max_tile_bytes)
  check_positive("max_layers", self.max_layers)
  check_positive("max_features_per_layer", self.max_features_per_layer)
  check_positive("max_keys_per_layer", self.max_keys_per_layer)
  check_positive("max_values_per_layer", self.max_values_per_layer)
  check_positive("max_tags_per_feature", self.max_tags_per_feature)
  check_positive(
    "max_geometry_words_per_feature",
    self.max_geometry_words_per_feature,
  )
  check_positive("max_string_bytes", self.max_string_bytes)
  check_positive("max_submessage_bytes", self.max_submessage_bytes)
  check_positive("max_unknown_fields", self.max_unknown_fields)
  if self.max_submessage_bytes > self.max_tile_bytes {
    raise @error.MvtError::InvalidArgument(
      "max_submessage_bytes must not exceed max_tile_bytes",
    )
  }
}

///|
pub fn DecodeLimits::check_tile_bytes(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("tile_bytes", actual, self.max_tile_bytes)
}

///|
pub fn DecodeLimits::check_layers(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("layers", actual, self.max_layers)
}

///|
pub fn DecodeLimits::check_features(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("features_per_layer", actual, self.max_features_per_layer)
}

///|
pub fn DecodeLimits::check_keys(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("keys_per_layer", actual, self.max_keys_per_layer)
}

///|
pub fn DecodeLimits::check_values(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("values_per_layer", actual, self.max_values_per_layer)
}

///|
pub fn DecodeLimits::check_tags(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("tags_per_feature", actual, self.max_tags_per_feature)
}

///|
pub fn DecodeLimits::check_geometry_words(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit(
    "geometry_words_per_feature",
    actual,
    self.max_geometry_words_per_feature,
  )
}

///|
pub fn DecodeLimits::check_string_bytes(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("string_bytes", actual, self.max_string_bytes)
}

///|
pub fn DecodeLimits::check_submessage_bytes(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("submessage_bytes", actual, self.max_submessage_bytes)
}

///|
pub fn DecodeLimits::check_unknown_fields(
  self : DecodeLimits,
  actual : Int,
) -> Unit raise @error.MvtError {
  check_limit("unknown_fields", actual, self.max_unknown_fields)
}

///|
fn check_positive(name : String, value : Int) -> Unit raise @error.MvtError {
  if value <= 0 {
    raise @error.MvtError::InvalidArgument(name + " must be positive")
  }
}

///|
fn check_limit(
  name : String,
  actual : Int,
  maximum : Int,
) -> Unit raise @error.MvtError {
  if actual < 0 {
    raise @error.MvtError::InvalidArgument(name + " count must not be negative")
  }
  if actual > maximum {
    raise @error.MvtError::ResourceLimit(
      limit=name,
      actual=actual.to_int64(),
      maximum=maximum.to_int64(),
    )
  }
}
