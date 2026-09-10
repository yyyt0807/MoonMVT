///|
/// Bounded cursor over one protobuf message. Readers never expose unchecked
/// indexes into the source Bytes value.
pub(all) struct Reader {
  data : Bytes
  mut cursor : Int
  end : Int
  limits : @limits.DecodeLimits
  mut unknown_fields : Int
}

///|
pub fn Reader::new(
  data : Bytes,
  limits? : @limits.DecodeLimits = @limits.DecodeLimits::standard(),
) -> Reader raise @error.MvtError {
  limits.validate()
  limits.check_tile_bytes(data.length())
  { data, cursor: 0, end: data.length(), limits, unknown_fields: 0, }
}

///|
fn Reader::from_range(
  self : Reader,
  range : ByteRange,
) -> Reader raise @error.MvtError {
  if range.start < 0 || range.end < range.start || range.end > self.end {
    raise @error.MvtError::InvalidArgument("subreader range is invalid")
  }
  self.limits.check_submessage_bytes(range.length())
  {
    data: self.data,
    cursor: range.start,
    end: range.end,
    limits: self.limits,
    unknown_fields: 0,
  }
}

///|
pub fn Reader::position(self : Reader) -> Int {
  self.cursor
}

///|
pub fn Reader::remaining(self : Reader) -> Int {
  self.end - self.cursor
}

///|
pub fn Reader::is_done(self : Reader) -> Bool {
  self.cursor == self.end
}

///|
pub fn Reader::unknown_field_count(self : Reader) -> Int {
  self.unknown_fields
}

///|
pub fn Reader::read_key(self : Reader) -> FieldKey raise @error.MvtError {
  let start = self.cursor
  let raw = self.read_varint("field key")
  decode_field_key(raw, start)
}

///|
pub fn Reader::read_varint(
  self : Reader,
  context : String,
) -> UInt64 raise @error.MvtError {
  if self.cursor >= self.end {
    raise @error.MvtError::TruncatedInput(offset=self.cursor, context~)
  }
  let (value, next) = decode_varint_bounded(
    self.data,
    self.cursor,
    self.end,
    context,
  )
  self.cursor = next
  value
}

///|
fn decode_varint_bounded(
  data : Bytes,
  offset : Int,
  end : Int,
  context : String,
) -> (UInt64, Int) raise @error.MvtError {
  let mut value = 0UL
  let mut shift = 0
  let mut cursor = offset
  while cursor < end && shift < 70 {
    let byte = data[cursor]
    let payload = (byte.to_int() & 0x7f).to_uint64()
    if shift == 63 && payload > 1UL {
      raise @error.MvtError::NumericOverflow(path=context)
    }
    if shift > 63 && payload != 0UL {
      raise @error.MvtError::NumericOverflow(path=context)
    }
    value = value | (payload << shift)
    cursor += 1
    if (byte.to_int() & 0x80) == 0 {
      if cursor - offset != varint_length(value) {
        raise @error.MvtError::InvalidWire(
          offset~,
          detail="non-canonical varint encoding in " + context,
        )
      }
      return (value, cursor)
    }
    shift += 7
  }
  if cursor >= end {
    raise @error.MvtError::TruncatedInput(offset=cursor, context~)
  }
  raise @error.MvtError::NumericOverflow(path=context)
}

///|
pub fn Reader::read_fixed32(
  self : Reader,
  context : String,
) -> UInt raise @error.MvtError {
  self.require_bytes(4, context)
  let offset = self.cursor
  self.cursor += 4
  self.data[offset].to_uint() |
  (self.data[offset + 1].to_uint() << 8) |
  (self.data[offset + 2].to_uint() << 16) |
  (self.data[offset + 3].to_uint() << 24)
}

///|
pub fn Reader::read_fixed64(
  self : Reader,
  context : String,
) -> UInt64 raise @error.MvtError {
  self.require_bytes(8, context)
  let offset = self.cursor
  let mut value = 0UL
  for index in 0..<8 {
    value = value | (self.data[offset + index].to_uint64() << (index * 8))
  }
  self.cursor += 8
  value
}

///|
pub fn Reader::read_length_range(
  self : Reader,
  context : String,
) -> ByteRange raise @error.MvtError {
  let length64 = self.read_varint(context + " length")
  if length64 > 2147483647UL {
    raise @error.MvtError::NumericOverflow(path=context + " length")
  }
  let length = length64.to_int()
  self.limits.check_submessage_bytes(length)
  self.require_bytes(length, context)
  let range : ByteRange = { start: self.cursor, end: self.cursor + length, }
  self.cursor += length
  range
}

///|
pub fn Reader::read_subreader(
  self : Reader,
  context : String,
) -> Reader raise @error.MvtError {
  self.from_range(self.read_length_range(context))
}

///|
pub fn Reader::read_bytes(
  self : Reader,
  context : String,
) -> Bytes raise @error.MvtError {
  let range = self.read_length_range(context)
  self.data[range.start:range.end].to_owned()
}

///|
pub fn Reader::read_string(
  self : Reader,
  path : String,
) -> String raise @error.MvtError {
  let range = self.read_length_range(path)
  self.limits.check_string_bytes(range.length())
  @utf8.decode(self.data[range.start:range.end]) catch {
    _ => raise @error.MvtError::InvalidUtf8(path~)
  }
}

///|
pub fn Reader::skip_field(
  self : Reader,
  key : FieldKey,
) -> Unit raise @error.MvtError {
  self.unknown_fields += 1
  self.limits.check_unknown_fields(self.unknown_fields)
  match key.wire_type {
    Varint => ignore(self.read_varint("unknown varint field"))
    Fixed64 => {
      self.require_bytes(8, "unknown fixed64 field")
      self.cursor += 8
    }
    LengthDelimited => ignore(self.read_length_range("unknown field"))
    Fixed32 => {
      self.require_bytes(4, "unknown fixed32 field")
      self.cursor += 4
    }
  }
}

///|
pub fn Reader::expect_wire(
  self : Reader,
  key : FieldKey,
  expected : WireType,
  path : String,
) -> Unit raise @error.MvtError {
  if key.wire_type != expected {
    raise @error.MvtError::InvalidWire(
      offset=self.cursor,
      detail="\{path} expects wire type \{wire_type_number(expected)}, got \{wire_type_number(key.wire_type)}",
    )
  }
}

///|
fn Reader::require_bytes(
  self : Reader,
  count : Int,
  context : String,
) -> Unit raise @error.MvtError {
  if count < 0 {
    raise @error.MvtError::InvalidArgument("byte count must not be negative")
  }
  if count > self.remaining() {
    raise @error.MvtError::TruncatedInput(offset=self.cursor, context~)
  }
}

///|
/// Decode a packed repeated uint32 field into Int values.
pub fn Reader::read_packed_uint32(
  self : Reader,
  path : String,
  maximum_words : Int,
) -> Array[Int] raise @error.MvtError {
  let packed = self.read_subreader(path)
  let values : Array[Int] = []
  while !packed.is_done() {
    if values.length() >= maximum_words {
      raise @error.MvtError::ResourceLimit(
        limit=path,
        actual=(values.length() + 1).to_int64(),
        maximum=maximum_words.to_int64(),
      )
    }
    let value = packed.read_varint(path)
    if value > 0xffffffffUL {
      raise @error.MvtError::NumericOverflow(path~)
    }
    values.push(value.to_int())
  }
  values
}

///|
/// Decode packed uint32 words without losing the upper half of the UInt range.
/// MVT geometry parameters use all 32 bits, so this is distinct from the
/// dictionary-index helper above.
pub fn Reader::read_packed_words(
  self : Reader,
  path : String,
  maximum_words : Int,
) -> Array[UInt] raise @error.MvtError {
  let packed = self.read_subreader(path)
  let values : Array[UInt] = []
  while !packed.is_done() {
    if values.length() >= maximum_words {
      raise @error.MvtError::ResourceLimit(
        limit=path,
        actual=(values.length() + 1).to_int64(),
        maximum=maximum_words.to_int64(),
      )
    }
    let value = packed.read_varint(path)
    if value > 0xffffffffUL {
      raise @error.MvtError::NumericOverflow(path~)
    }
    values.push(value.to_uint())
  }
  values
}
