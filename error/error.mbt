///|
/// Stable error categories returned by MoonMVT.
pub(all) suberror MvtError {
  InvalidArgument(String)
  TruncatedInput(offset~ : Int, context~ : String)
  InvalidWire(offset~ : Int, detail~ : String)
  InvalidTile(path~ : String, detail~ : String)
  InvalidGeometry(path~ : String, detail~ : String)
  InvalidUtf8(path~ : String)
  NumericOverflow(path~ : String)
  ResourceLimit(limit~ : String, actual~ : Int64, maximum~ : Int64)
  Unsupported(path~ : String, detail~ : String)
} derive(Debug, Eq)

///|
/// Stable machine-readable code for integrations and tests.
pub fn MvtError::code(self : MvtError) -> String {
  match self {
    InvalidArgument(_) => "MOONMVT_ARGUMENT"
    TruncatedInput(..) => "MOONMVT_TRUNCATED"
    InvalidWire(..) => "MOONMVT_WIRE"
    InvalidTile(..) => "MOONMVT_TILE"
    InvalidGeometry(..) => "MOONMVT_GEOMETRY"
    InvalidUtf8(..) => "MOONMVT_UTF8"
    NumericOverflow(..) => "MOONMVT_OVERFLOW"
    ResourceLimit(..) => "MOONMVT_RESOURCE_LIMIT"
    Unsupported(..) => "MOONMVT_UNSUPPORTED"
  }
}

///|
/// Human-readable error detail. The stable code should be used for branching.
pub fn MvtError::message(self : MvtError) -> String {
  match self {
    InvalidArgument(detail) => detail
    TruncatedInput(offset~, context~) =>
      "truncated input at byte \{offset} while reading \{context}"
    InvalidWire(offset~, detail~) =>
      "invalid protobuf wire data at byte \{offset}: \{detail}"
    InvalidTile(path~, detail~) => "invalid tile at \{path}: \{detail}"
    InvalidGeometry(path~, detail~) =>
      "invalid geometry at \{path}: \{detail}"
    InvalidUtf8(path~) => "invalid UTF-8 at \{path}"
    NumericOverflow(path~) => "numeric overflow at \{path}"
    ResourceLimit(limit~, actual~, maximum~) =>
      "resource limit \{limit} exceeded: \{actual} > \{maximum}"
    Unsupported(path~, detail~) => "unsupported value at \{path}: \{detail}"
  }
}

///|
/// True when retrying with a larger DecodeLimits value can make this operation
/// succeed without changing the input bytes.
pub fn MvtError::is_limit_error(self : MvtError) -> Bool {
  match self {
    ResourceLimit(..) => true
    _ => false
  }
}

///|
/// Classify malformed external input separately from caller API misuse.
pub fn MvtError::is_malformed_input(self : MvtError) -> Bool {
  match self {
    TruncatedInput(..)
    | InvalidWire(..)
    | InvalidTile(..)
    | InvalidGeometry(..)
    | InvalidUtf8(..)
    | NumericOverflow(..) => true
    _ => false
  }
}

