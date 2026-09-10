///|
test "error codes are stable and category-specific" {
  let cases : Array[(MvtError, String)] = [
    (MvtError::InvalidArgument("x"), "MOONMVT_ARGUMENT"),
    (MvtError::TruncatedInput(offset=3, context="varint"), "MOONMVT_TRUNCATED"),
    (MvtError::InvalidWire(offset=1, detail="bad tag"), "MOONMVT_WIRE"),
    (MvtError::InvalidTile(path="tile", detail="empty"), "MOONMVT_TILE"),
    (
      MvtError::InvalidGeometry(path="layer[0]", detail="bad command"),
      "MOONMVT_GEOMETRY",
    ),
    (MvtError::InvalidUtf8(path="layer.name"), "MOONMVT_UTF8"),
    (MvtError::NumericOverflow(path="feature.id"), "MOONMVT_OVERFLOW"),
    (
      MvtError::ResourceLimit(limit="bytes", actual=9L, maximum=8L),
      "MOONMVT_RESOURCE_LIMIT",
    ),
    (MvtError::Unsupported(path="value", detail="group"), "MOONMVT_UNSUPPORTED"),
  ]
  for item in cases {
    let (error, expected) = item
    assert_eq(error.code(), expected)
  }
}

///|
test "limit and malformed classifications do not overlap" {
  let limit = MvtError::ResourceLimit(limit="layers", actual=2L, maximum=1L)
  assert_true(limit.is_limit_error())
  assert_false(limit.is_malformed_input())
  let malformed = MvtError::InvalidWire(offset=0, detail="zero field number")
  assert_false(malformed.is_limit_error())
  assert_true(malformed.is_malformed_input())
  let argument = MvtError::InvalidArgument("extent")
  assert_false(argument.is_limit_error())
  assert_false(argument.is_malformed_input())
}

///|
test "messages include actionable locations" {
  assert_eq(
    MvtError::TruncatedInput(offset=7, context="feature").message(),
    "truncated input at byte 7 while reading feature",
  )
  assert_eq(
    MvtError::InvalidGeometry(path="layers[2].features[4]", detail="missing MoveTo").message(),
    "invalid geometry at layers[2].features[4]: missing MoveTo",
  )
  assert_eq(
    MvtError::ResourceLimit(limit="commands", actual=11L, maximum=10L).message(),
    "resource limit commands exceeded: 11 > 10",
  )
}
