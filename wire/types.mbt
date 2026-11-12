///|
/// Protocol Buffers wire types accepted by MVT.
#derive(Debug, Eq)
pub(all) enum WireType {
  Varint
  Fixed64
  LengthDelimited
  Fixed32
}

///|
/// Decoded protobuf field key.
#derive(Debug, Eq)
pub(all) struct FieldKey {
  number : Int32
  wire_type : WireType
}

///|
/// A length-delimited slice into the original byte document.
#derive(Debug, Eq)
pub(all) struct ByteRange {
  start : Int32
  end : Int32
}

///|
pub fn ByteRange::length(self : ByteRange) -> Int32 {
  self.end - self.start
}

///|
pub fn ByteRange::is_empty(self : ByteRange) -> Bool {
  self.start == self.end
}

///|
pub fn wire_type_number(wire_type : WireType) -> Int32 {
  match wire_type {
    Varint => 0
    Fixed64 => 1
    LengthDelimited => 2
    Fixed32 => 5
  }
}

///|
pub fn wire_type_from_number(
  value : Int32,
  offset : Int32,
) -> WireType raise @error.MvtError {
  match value {
    0 => Varint
    1 => Fixed64
    2 => LengthDelimited
    5 => Fixed32
    _ =>
      raise @error.MvtError::InvalidWire(
        offset~,
        detail="unsupported wire type \{value}",
      )
  }
}

///|
pub extend ByteRange with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ByteRange with Eq::{not_equal, equal}

///|
pub extend FieldKey with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FieldKey with Eq::{not_equal, equal}

///|
pub extend WireType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend WireType with Eq::{not_equal, equal}
