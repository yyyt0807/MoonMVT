///|
/// Deterministically encode one complete MVT document.
pub fn encode_tile(tile : @model.Tile) -> Bytes raise @error.MvtError {
  validate_tile(tile)
  let writer = @wire.Writer::new()
  for layer in tile.layers {
    writer.write_message_field(3, encode_layer_message(layer))
  }
  writer.finish()
}

///|
fn encode_layer_message(
  layer : @model.Layer,
) -> @wire.Writer raise @error.MvtError {
  let writer = @wire.Writer::new()
  writer.write_string_field(1, layer.name)
  for feature in layer.features {
    writer.write_message_field(2, encode_feature_message(feature))
  }
  for key in layer.keys {
    writer.write_string_field(3, key)
  }
  for value in layer.values {
    writer.write_message_field(4, encode_value_message(value))
  }
  writer.write_varint_field(5, layer.extent.to_uint64())
  writer.write_varint_field(15, layer.version.to_uint64())
  writer
}

///|
fn encode_feature_message(
  feature : @model.Feature,
) -> @wire.Writer raise @error.MvtError {
  let writer = @wire.Writer::new()
  match feature.id {
    Some(id) => writer.write_varint_field(1, id)
    None => ()
  }
  writer.write_packed_uint32(2, feature.tags)
  writer.write_varint_field(3, feature.geometry_type.number().to_uint64())
  writer.write_packed_words(4, feature.geometry)
  writer
}

///|
fn encode_value_message(
  value : @model.MvtValue,
) -> @wire.Writer raise @error.MvtError {
  let writer = @wire.Writer::new()
  match value {
    @model.StringValue(value) => writer.write_string_field(1, value)
    @model.FloatValue(value) =>
      writer.write_fixed32_field(2, value.reinterpret_as_uint())
    @model.DoubleValue(value) =>
      writer.write_fixed64_field(3, value.reinterpret_as_uint64())
    @model.IntValue(value) =>
      writer.write_varint_field(4, value.reinterpret_as_uint64())
    @model.UIntValue(value) => writer.write_varint_field(5, value)
    @model.SIntValue(value) => writer.write_sint64_field(6, value)
    @model.BoolValue(value) =>
      writer.write_varint_field(7, if value { 1UL } else { 0UL })
  }
  writer
}
