///|
fn main {
  run() catch {
    error => abort("MoonMVT example failed: \{error}")
  }
}

///|
fn run() -> Unit raise {
  let places = @builder.LayerBuilder::new("places")
  places.add_points(
    [@model.Point::new(1200, 900)],
    properties=[
      @builder.property("name", @model.MvtValue::StringValue("Moon Harbor")),
      @builder.property("capital", @model.MvtValue::BoolValue(true)),
    ],
    id=Some(1UL),
  )
  let roads = @builder.LayerBuilder::new("roads")
  roads.add_lines(
    [
      [
        @model.Point::new(0, 2048),
        @model.Point::new(1000, 1800),
        @model.Point::new(2500, 2300),
        @model.Point::new(4096, 2000),
      ],
    ],
    properties=[
      @builder.property("class", @model.MvtValue::StringValue("primary")),
    ],
    id=Some(7UL),
  )
  let land = @builder.LayerBuilder::new("land")
  land.add_polygons(
    [
      [
        @model.Point::new(100, 100),
        @model.Point::new(3900, 100),
        @model.Point::new(3900, 3900),
        @model.Point::new(100, 3900),
      ],
    ],
    properties=[
      @builder.property("kind", @model.MvtValue::StringValue("island")),
    ],
  )
  let tile_builder = @builder.TileBuilder::new()
  tile_builder.add_built_layer(places)
  tile_builder.add_built_layer(roads)
  tile_builder.add_built_layer(land)
  let bytes = @codec.encode_tile(tile_builder.finish())
  let decoded = @codec.decode_tile(bytes)
  let statistics = @query.tile_statistics(decoded)
  println("encoded bytes: \{bytes.length()}")
  println("layers: \{statistics.layers}")
  println("features: \{statistics.features}")
  println("decoded points: \{statistics.decoded_points}")
  println("canonical: \{@codec.is_canonical(bytes)}")
}
