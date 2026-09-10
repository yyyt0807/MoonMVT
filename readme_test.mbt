///|
/// Mirrors the executable workflow shown in README.mbt.md.
test "README typed tile workflow" {
  let places = @builder.LayerBuilder::new("places")
  places.add_points([@model.Point::new(1200, 900)], id=Some(1UL), properties=[
    @builder.property("name", @model.MvtValue::StringValue("Moon Harbor")),
    @builder.property("capital", @model.MvtValue::BoolValue(true)),
  ])
  let tile_builder = @builder.TileBuilder::new()
  tile_builder.add_built_layer(places)
  let bytes = @codec.encode_tile(tile_builder.finish())
  let tile = @codec.decode_tile(bytes)
  assert_eq(tile.layers.length(), 1)
  assert_eq(@query.tile_statistics(tile).features, 1)
  assert_true(@codec.is_canonical(bytes))
}
