///|
/// Typed value variants defined by `vector_tile.proto`.
pub(all) enum MvtValue {
  StringValue(String)
  FloatValue(Float)
  DoubleValue(Double)
  IntValue(Int64)
  UIntValue(UInt64)
  SIntValue(Int64)
  BoolValue(Bool)
} derive(Debug, Eq)

///|
/// Stable value kind used by diagnostics and applications.
pub(all) enum ValueKind {
  String
  Float
  Double
  Int
  UInt
  SInt
  Bool
} derive(Debug, Eq)

///|
pub fn MvtValue::kind(self : MvtValue) -> ValueKind {
  match self {
    StringValue(_) => String
    FloatValue(_) => Float
    DoubleValue(_) => Double
    IntValue(_) => Int
    UIntValue(_) => UInt
    SIntValue(_) => SInt
    BoolValue(_) => Bool
  }
}

///|
/// Stable lowercase kind name suitable for reports and JSON adapters.
pub fn ValueKind::name(self : ValueKind) -> String {
  match self {
    String => "string"
    Float => "float"
    Double => "double"
    Int => "int"
    UInt => "uint"
    SInt => "sint"
    Bool => "bool"
  }
}

///|
pub fn MvtValue::display(self : MvtValue) -> String {
  match self {
    StringValue(value) => value
    FloatValue(value) => value.to_string()
    DoubleValue(value) => value.to_string()
    IntValue(value) => value.to_string()
    UIntValue(value) => value.to_string()
    SIntValue(value) => value.to_string()
    BoolValue(value) => value.to_string()
  }
}

///|
pub fn MvtValue::as_string(self : MvtValue) -> String? {
  match self {
    StringValue(value) => Some(value)
    _ => None
  }
}

///|
pub fn MvtValue::as_bool(self : MvtValue) -> Bool? {
  match self {
    BoolValue(value) => Some(value)
    _ => None
  }
}

///|
pub fn MvtValue::as_int64(self : MvtValue) -> Int64? {
  match self {
    IntValue(value) | SIntValue(value) => Some(value)
    _ => None
  }
}

///|
pub fn MvtValue::as_uint64(self : MvtValue) -> UInt64? {
  match self {
    UIntValue(value) => Some(value)
    _ => None
  }
}

///|
pub fn MvtValue::as_double(self : MvtValue) -> Double? {
  match self {
    FloatValue(value) => Some(value.to_double())
    DoubleValue(value) => Some(value)
    _ => None
  }
}

///|
/// Equality used for deterministic value dictionary interning. IEEE NaN values
/// are interned by their exact payload bits rather than by floating comparison.
pub fn MvtValue::dictionary_equal(
  self : MvtValue,
  other : MvtValue,
) -> Bool {
  match (self, other) {
    (StringValue(left), StringValue(right)) => left == right
    (FloatValue(left), FloatValue(right)) =>
      left.reinterpret_as_uint() == right.reinterpret_as_uint()
    (DoubleValue(left), DoubleValue(right)) =>
      left.reinterpret_as_uint64() == right.reinterpret_as_uint64()
    (IntValue(left), IntValue(right)) => left == right
    (UIntValue(left), UIntValue(right)) => left == right
    (SIntValue(left), SIntValue(right)) => left == right
    (BoolValue(left), BoolValue(right)) => left == right
    _ => false
  }
}

///|
/// True for a finite floating-point value or any non-floating value.
pub fn MvtValue::is_finite(self : MvtValue) -> Bool {
  match self {
    FloatValue(value) => !value.is_nan() && !value.is_inf()
    DoubleValue(value) => !value.is_nan() && !value.is_inf()
    _ => true
  }
}

