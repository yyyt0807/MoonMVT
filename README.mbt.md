# MoonMVT

MoonMVT is a pure MoonBit Mapbox Vector Tile 2.1 codec and typed tile builder.
It works with tile-local integer coordinates and is portable across MoonBit
targets. Projection, networking, map rendering, and storage are intentionally
outside the module boundary.

Install the published module with:

```text
moon add yyyt0807/moonmvt@0.1.0
```

The following executable documentation builds, encodes, decodes, and queries a
tile without exposing property dictionary indexes or geometry command words to
the caller.

```mbt check
///|
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
```

See the repository `README.md` for geometry conventions, resource limits,
filtering, package architecture, security policy, and explicit non-goals.
