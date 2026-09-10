///|
fn main {
  run() catch {
    error => abort("MoonMVT filter example failed: \{error}")
  }
}

///|
fn run() -> Unit raise {
  let source = @builder.LayerBuilder::new("places", extent=256)
  for
    item in [
      (1UL, "Moon Harbor", true, @model.Point::new(20, 30)),
      (2UL, "Crater Market", false, @model.Point::new(180, 160)),
      (3UL, "Luna Port", true, @model.Point::new(230, 40)),
    ] {
    let (id, name, capital, point) = item
    source.add_points([point], id=Some(id), properties=[
      @builder.property("name", @model.MvtValue::StringValue(name)),
      @builder.property("capital", @model.MvtValue::BoolValue(capital)),
    ])
  }
  let encoded = @codec.encode_tile({ layers: [source.finish()], })
  let decoded = @codec.decode_tile(encoded)
  let capitals = @query.filter_property_equals(
    decoded.layers[0],
    "capital",
    @model.MvtValue::BoolValue(true),
  )
  let eastern = @query.filter_intersects(capitals, {
    min_x: 128,
    min_y: 0,
    max_x: 256,
    max_y: 256,
  })
  let output = @codec.encode_tile({ layers: [eastern], })
  println("source features: \{decoded.layers[0].features.length()}")
  println("selected features: \{eastern.features.length()}")
  println("selected tile bytes: \{output.length()}")
}
