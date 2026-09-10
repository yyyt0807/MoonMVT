///|
/// Decode and structurally validate a complete MVT document.
pub fn decode_tile(
  data : Bytes,
  limits? : @limits.DecodeLimits = @limits.DecodeLimits::standard(),
) -> @model.Tile raise @error.MvtError {
  let reader = @wire.Reader::new(data, limits~)
  let layers : Array[@model.Layer] = []
  while !reader.is_done() {
    let key = reader.read_key()
    if key.number == 3 {
      reader.expect_wire(key, @wire.WireType::LengthDelimited, "tile.layers")
      limits.check_layers(layers.length() + 1)
      layers.push(
        decode_layer(
          reader.read_subreader("tile.layers"),
          layers.length(),
          limits,
        ),
      )
    } else {
      reader.skip_field(key)
    }
  }
  let tile : @model.Tile = { layers, }
  validate_tile(tile)
  tile
}

///|
fn decode_layer(
  reader : @wire.Reader,
  layer_index : Int,
  limits : @limits.DecodeLimits,
) -> @model.Layer raise @error.MvtError {
  let path = "layers[\{layer_index}]"
  let mut name : String? = None
  let features : Array[@model.Feature] = []
  let keys : Array[String] = []
  let values : Array[@model.MvtValue] = []
  let mut extent : Int? = None
  let mut version : Int? = None
  while !reader.is_done() {
    let key = reader.read_key()
    match key.number {
      1 => {
        reader.expect_wire(key, @wire.WireType::LengthDelimited, path + ".name")
        ensure_absent(name is None, path + ".name")
        name = Some(reader.read_string(path + ".name"))
      }
      2 => {
        reader.expect_wire(
          key,
          @wire.WireType::LengthDelimited,
          path + ".features",
        )
        limits.check_features(features.length() + 1)
        features.push(
          decode_feature(
            reader.read_subreader(path + ".features"),
            path + ".features[\{features.length()}]",
            limits,
          ),
        )
      }
      3 => {
        reader.expect_wire(key, @wire.WireType::LengthDelimited, path + ".keys")
        limits.check_keys(keys.length() + 1)
        keys.push(reader.read_string(path + ".keys[\{keys.length()}]"))
      }
      4 => {
        reader.expect_wire(
          key,
          @wire.WireType::LengthDelimited,
          path + ".values",
        )
        limits.check_values(values.length() + 1)
        values.push(
          decode_value(
            reader.read_subreader(path + ".values"),
            path + ".values[\{values.length()}]",
          ),
        )
      }
      5 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".extent")
        ensure_absent(extent is None, path + ".extent")
        extent = Some(read_positive_int(reader, path + ".extent"))
      }
      15 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".version")
        ensure_absent(version is None, path + ".version")
        version = Some(read_nonnegative_int(reader, path + ".version"))
      }
      _ => reader.skip_field(key)
    }
  }
  let layer : @model.Layer = {
    name: match name {
      Some(value) => value
      None =>
        raise @error.MvtError::InvalidTile(
          path=path + ".name",
          detail="required field is missing",
        )
    },
    features,
    keys,
    values,
    extent: extent.unwrap_or(4096),
    version: match version {
      Some(value) => value
      None =>
        raise @error.MvtError::InvalidTile(
          path=path + ".version",
          detail="required field is missing",
        )
    },
  }
  validate_layer(layer, path~)
  layer
}

///|
fn decode_feature(
  reader : @wire.Reader,
  path : String,
  limits : @limits.DecodeLimits,
) -> @model.Feature raise @error.MvtError {
  let mut id : UInt64? = None
  let tags : Array[Int] = []
  let mut geometry_type : @model.GeomType? = None
  let geometry : Array[UInt] = []
  while !reader.is_done() {
    let key = reader.read_key()
    match key.number {
      1 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".id")
        ensure_absent(id is None, path + ".id")
        id = Some(reader.read_varint(path + ".id"))
      }
      2 => {
        reader.expect_wire(key, @wire.WireType::LengthDelimited, path + ".tags")
        let part = reader.read_packed_uint32(
          path + ".tags",
          limits.max_tags_per_feature - tags.length(),
        )
        for value in part {
          tags.push(value)
        }
        limits.check_tags(tags.length())
      }
      3 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".type")
        ensure_absent(geometry_type is None, path + ".type")
        let raw = read_nonnegative_int(reader, path + ".type")
        geometry_type = Some(@model.GeomType::from_number(raw, path + ".type"))
      }
      4 => {
        reader.expect_wire(
          key,
          @wire.WireType::LengthDelimited,
          path + ".geometry",
        )
        let part = reader.read_packed_words(
          path + ".geometry",
          limits.max_geometry_words_per_feature - geometry.length(),
        )
        for value in part {
          geometry.push(value)
        }
        limits.check_geometry_words(geometry.length())
      }
      _ => reader.skip_field(key)
    }
  }
  {
    id,
    tags,
    geometry_type: geometry_type.unwrap_or(@model.GeomType::Unknown),
    geometry,
  }
}

///|
fn decode_value(
  reader : @wire.Reader,
  path : String,
) -> @model.MvtValue raise @error.MvtError {
  let mut decoded : @model.MvtValue? = None
  while !reader.is_done() {
    let key = reader.read_key()
    match key.number {
      1 => {
        reader.expect_wire(
          key,
          @wire.WireType::LengthDelimited,
          path + ".string_value",
        )
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::StringValue(
            reader.read_string(path + ".string_value"),
          ),
        )
      }
      2 => {
        reader.expect_wire(key, @wire.WireType::Fixed32, path + ".float_value")
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::FloatValue(
            Float::reinterpret_from_uint(
              reader.read_fixed32(path + ".float_value"),
            ),
          ),
        )
      }
      3 => {
        reader.expect_wire(key, @wire.WireType::Fixed64, path + ".double_value")
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::DoubleValue(
            reader.read_fixed64(path + ".double_value").reinterpret_as_double(),
          ),
        )
      }
      4 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".int_value")
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::IntValue(
            reader.read_varint(path + ".int_value").reinterpret_as_int64(),
          ),
        )
      }
      5 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".uint_value")
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::UIntValue(reader.read_varint(path + ".uint_value")),
        )
      }
      6 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".sint_value")
        ensure_absent(decoded is None, path)
        decoded = Some(
          @model.MvtValue::SIntValue(
            @wire.zigzag_decode_i64(reader.read_varint(path + ".sint_value")),
          ),
        )
      }
      7 => {
        reader.expect_wire(key, @wire.WireType::Varint, path + ".bool_value")
        ensure_absent(decoded is None, path)
        let raw = reader.read_varint(path + ".bool_value")
        if raw > 1UL {
          raise @error.MvtError::InvalidTile(
            path=path + ".bool_value",
            detail="boolean varint must be 0 or 1",
          )
        }
        decoded = Some(@model.MvtValue::BoolValue(raw == 1UL))
      }
      _ => reader.skip_field(key)
    }
  }
  match decoded {
    Some(value) => value
    None =>
      raise @error.MvtError::InvalidTile(
        path~,
        detail="value message must contain exactly one typed value",
      )
  }
}

///|
fn read_nonnegative_int(
  reader : @wire.Reader,
  path : String,
) -> Int raise @error.MvtError {
  let raw = reader.read_varint(path)
  if raw > 2147483647UL {
    raise @error.MvtError::NumericOverflow(path~)
  }
  raw.to_int()
}

///|
fn read_positive_int(
  reader : @wire.Reader,
  path : String,
) -> Int raise @error.MvtError {
  let value = read_nonnegative_int(reader, path)
  if value == 0 {
    raise @error.MvtError::InvalidTile(path~, detail="value must be positive")
  }
  value
}

///|
fn ensure_absent(absent : Bool, path : String) -> Unit raise @error.MvtError {
  if !absent {
    raise @error.MvtError::InvalidTile(
      path~,
      detail="singular field appears more than once",
    )
  }
}
