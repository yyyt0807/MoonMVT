///|
test "value kinds and names cover every MVT variant" {
  let values : Array[(@model.MvtValue, String)] = [
    (@model.MvtValue::StringValue("road"), "string"),
    (@model.MvtValue::FloatValue(1.5), "float"),
    (@model.MvtValue::DoubleValue(2.5), "double"),
    (@model.MvtValue::IntValue(-3L), "int"),
    (@model.MvtValue::UIntValue(4UL), "uint"),
    (@model.MvtValue::SIntValue(-5L), "sint"),
    (@model.MvtValue::BoolValue(true), "bool"),
  ]
  for item in values {
    let (value, name) = item
    assert_eq(value.kind().name(), name)
  }
}

///|
test "typed accessors do not coerce integer variants" {
  assert_eq(@model.MvtValue::StringValue("x").as_string(), Some("x"))
  assert_eq(@model.MvtValue::StringValue("x").as_bool(), None)
  assert_eq(@model.MvtValue::BoolValue(false).as_bool(), Some(false))
  assert_eq(@model.MvtValue::IntValue(-2L).as_int64(), Some(-2L))
  assert_eq(@model.MvtValue::SIntValue(-2L).as_int64(), Some(-2L))
  assert_eq(@model.MvtValue::UIntValue(2UL).as_int64(), None)
  assert_eq(@model.MvtValue::UIntValue(2UL).as_uint64(), Some(2UL))
}

///|
test "float accessors widen Float but reject integers" {
  assert_eq(@model.MvtValue::FloatValue(1.25).as_double(), Some(1.25))
  assert_eq(@model.MvtValue::DoubleValue(2.5).as_double(), Some(2.5))
  assert_eq(@model.MvtValue::IntValue(2L).as_double(), None)
}

///|
test "dictionary equality distinguishes wire variants" {
  assert_true(
    @model.MvtValue::StringValue("road").dictionary_equal(
      @model.MvtValue::StringValue("road"),
    ),
  )
  assert_false(
    @model.MvtValue::IntValue(1L).dictionary_equal(
      @model.MvtValue::SIntValue(1L),
    ),
  )
  assert_false(
    @model.MvtValue::FloatValue(1.0).dictionary_equal(
      @model.MvtValue::DoubleValue(1.0),
    ),
  )
}

///|
test "dictionary equality handles NaN by exact bits" {
  let nan_a = Float::reinterpret_from_uint(0x7fc00001U)
  let nan_b = Float::reinterpret_from_uint(0x7fc00001U)
  let nan_c = Float::reinterpret_from_uint(0x7fc00002U)
  assert_true(
    @model.MvtValue::FloatValue(nan_a).dictionary_equal(
      @model.MvtValue::FloatValue(nan_b),
    ),
  )
  assert_false(
    @model.MvtValue::FloatValue(nan_a).dictionary_equal(
      @model.MvtValue::FloatValue(nan_c),
    ),
  )
  assert_false(@model.MvtValue::FloatValue(nan_a).is_finite())
  assert_true(@model.MvtValue::DoubleValue(42.0).is_finite())
}
