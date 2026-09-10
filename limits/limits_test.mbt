///|
test "standard and constrained limits are valid" {
  DecodeLimits::standard().validate()
  DecodeLimits::constrained().validate()
  assert_true(
    DecodeLimits::standard().max_tile_bytes >
    DecodeLimits::constrained().max_tile_bytes,
  )
}

///|
test "all public counters accept their exact ceilings" {
  let limits = DecodeLimits::constrained()
  limits.check_tile_bytes(limits.max_tile_bytes)
  limits.check_layers(limits.max_layers)
  limits.check_features(limits.max_features_per_layer)
  limits.check_keys(limits.max_keys_per_layer)
  limits.check_values(limits.max_values_per_layer)
  limits.check_tags(limits.max_tags_per_feature)
  limits.check_geometry_words(limits.max_geometry_words_per_feature)
  limits.check_string_bytes(limits.max_string_bytes)
  limits.check_submessage_bytes(limits.max_submessage_bytes)
  limits.check_unknown_fields(limits.max_unknown_fields)
}

///|
test "counters reject values above their ceilings" {
  let limits = DecodeLimits::constrained()
  let mut failures = 0
  limits.check_layers(limits.max_layers + 1) catch { _ => failures += 1 }
  limits.check_features(limits.max_features_per_layer + 1) catch {
    _ => failures += 1
  }
  limits.check_keys(limits.max_keys_per_layer + 1) catch { _ => failures += 1 }
  limits.check_values(limits.max_values_per_layer + 1) catch {
    _ => failures += 1
  }
  limits.check_tags(limits.max_tags_per_feature + 1) catch {
    _ => failures += 1
  }
  limits.check_geometry_words(limits.max_geometry_words_per_feature + 1) catch {
    _ => failures += 1
  }
  limits.check_string_bytes(limits.max_string_bytes + 1) catch {
    _ => failures += 1
  }
  limits.check_submessage_bytes(limits.max_submessage_bytes + 1) catch {
    _ => failures += 1
  }
  limits.check_unknown_fields(limits.max_unknown_fields + 1) catch {
    _ => failures += 1
  }
  assert_eq(failures, 9)
}

///|
test "negative counter is caller misuse instead of a resource limit" {
  let mut error_code = ""
  DecodeLimits::standard().check_layers(-1) catch {
    error => error_code = error.code()
  }
  assert_eq(error_code, "MOONMVT_ARGUMENT")
}

///|
test "invalid configurations are rejected" {
  let standard = DecodeLimits::standard()
  let zero_layers : DecodeLimits = { ..standard, max_layers: 0 }
  let mut zero_rejected = false
  zero_layers.validate() catch { _ => zero_rejected = true }
  assert_true(zero_rejected)
  let inconsistent : DecodeLimits = {
    ..standard,
    max_tile_bytes: 10,
    max_submessage_bytes: 11,
  }
  let mut inconsistent_rejected = false
  inconsistent.validate() catch { _ => inconsistent_rejected = true }
  assert_true(inconsistent_rejected)
}

