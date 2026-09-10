///|
/// Protocol Buffers wire types accepted by MVT.
pub(all) enum WireType {
  Varint
  Fixed64
  LengthDelimited
  Fixed32
} derive(Debug, Eq)

///|
/// Decoded protobuf field key.
pub(all) struct FieldKey {
  number : Int
  wire_type : WireType
} derive(Debug, Eq)

///|
/// A length-delimited slice into the original byte document.
pub(all) struct ByteRange {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
pub fn ByteRange::length(self : ByteRange) -> Int {
  self.end - self.start
}

///|
pub fn ByteRange::is_empty(self : ByteRange) -> Bool {
  self.start == self.end
}

///|
pub fn wire_type_number(wire_type : WireType) -> Int {
  match wire_type {
    Varint => 0
    Fixed64 => 1
    LengthDelimited => 2
    Fixed32 => 5
  }
}

///|
pub fn wire_type_from_number(
  value : Int,
  offset : Int,
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
