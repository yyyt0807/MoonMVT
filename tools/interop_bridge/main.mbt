///|
fn main {
  run() catch {
    error => abort("MoonMVT interoperability bridge failed: \{error}")
  }
}

///|
fn run() -> Unit raise {
  let args = @env.args()
  if args.length() == 1 || args[1] == "export" {
    emit_export_vectors()
    return
  }
  if args.length() != 4 || args[1] != "verify" {
    abort("usage: interop_bridge [export | verify CASE HEX]")
  }
  let bytes = @hex.decode(args[3])
  verify_import(args[2], @codec.decode_tile(bytes))
  println("PASS|python-to-moonbit|" + args[2])
}

///|
fn ensure(condition : Bool, message : String) -> Unit {
  if !condition {
    abort("semantic mismatch: " + message)
  }
}

///|
fn point(x : Int, y : Int) -> @model.Point {
  @model.Point::new(x, y)
}

///|
fn prop(key : String, value : @model.MvtValue) -> @model.Property {
  @builder.property(key, value)
}

///|
fn one_layer(layer : @builder.LayerBuilder) -> @model.Tile raise {
  let tile = @builder.TileBuilder::new()
  tile.add_built_layer(layer)
  tile.finish()
}

///|
fn export_point() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("point")
  layer.add_points([point(7, 11)], id=Some(101UL), properties=[
    prop("name", @model.MvtValue::StringValue("moon")),
    prop("ok", @model.MvtValue::BoolValue(true)),
  ])
  one_layer(layer)
}

///|
fn export_multipoint() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("multipoint")
  layer.add_points([point(1, 2), point(20, 30), point(-4, 8)], id=Some(102UL))
  one_layer(layer)
}

///|
fn export_line() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("line")
  layer.add_lines(
    [[point(0, 0), point(10, 5), point(30, 25)]],
    id=Some(103UL),
    properties=[prop("class", @model.MvtValue::StringValue("primary"))],
  )
  one_layer(layer)
}

///|
fn export_multiline() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("multiline")
  layer.add_lines(
    [
      [point(2, 2), point(4, 8)],
      [point(100, 80), point(90, 70), point(120, 60)],
    ],
    id=Some(104UL),
  )
  one_layer(layer)
}

///|
fn export_polygon() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("polygon")
  layer.add_polygons(
    [
      [point(0, 0), point(40, 0), point(40, 40), point(0, 40)],
      [point(10, 10), point(10, 30), point(30, 30), point(30, 10)],
    ],
    id=Some(105UL),
  )
  one_layer(layer)
}

///|
fn export_attributes() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("attributes", extent=512)
  layer.add_points([point(256, 256)], id=Some(106UL), properties=[
    prop("string", @model.MvtValue::StringValue("MoonMVT")),
    prop("float", @model.MvtValue::FloatValue(1.5)),
    prop("double", @model.MvtValue::DoubleValue(-2.25)),
    prop("int", @model.MvtValue::IntValue(-3L)),
    prop("uint", @model.MvtValue::UIntValue(4UL)),
    prop("sint", @model.MvtValue::SIntValue(-5L)),
    prop("bool", @model.MvtValue::BoolValue(false)),
  ])
  one_layer(layer)
}

///|
fn emit(name : String, tile : @model.Tile) -> Unit raise {
  let bytes = @codec.encode_tile(tile)
  println("MVT|" + name + "|" + @hex.encode(bytes))
}

///|
fn emit_export_vectors() -> Unit raise {
  emit("point", export_point())
  emit("multipoint", export_multipoint())
  emit("line", export_line())
  emit("multiline", export_multiline())
  emit("polygon", export_polygon())
  emit("attributes", export_attributes())
}

///|
fn verify_import(case_name : String, tile : @model.Tile) -> Unit raise {
  match case_name {
    "point" => verify_point(tile)
    "multipoint" => verify_multipoint(tile)
    "line" => verify_line(tile)
    "multiline" => verify_multiline(tile)
    "polygon" => verify_polygon(tile)
    "attributes" => verify_attributes(tile)
    _ => abort("unknown interoperability case: " + case_name)
  }
}

///|
fn only_feature(
  tile : @model.Tile,
  layer_name : String,
) -> (@model.Layer, @model.Feature) {
  ensure(tile.layers.length() == 1, layer_name + " layer count")
  let layer = tile.layers[0]
  ensure(layer.name == layer_name, layer_name + " layer name")
  ensure(layer.version == 2, layer_name + " layer version")
  ensure(layer.features.length() == 1, layer_name + " feature count")
  (layer, layer.features[0])
}

///|
fn verify_point(tile : @model.Tile) -> Unit raise {
  let (layer, feature) = only_feature(tile, "point")
  ensure(feature.id == Some(201UL), "point id")
  ensure(feature.geometry_type == @model.GeomType::Point, "point type")
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
  )
  ensure(geometry.paths.length() == 1, "point path count")
  ensure(geometry.paths[0].points == [point(7, 11)], "point coordinate")
  ensure(
    layer.property(feature, "name") ==
    Some(@model.MvtValue::StringValue("python")),
    "point string property",
  )
  ensure(
    layer.property(feature, "ok") == Some(@model.MvtValue::BoolValue(true)),
    "point bool property",
  )
}

///|
fn verify_multipoint(tile : @model.Tile) -> Unit raise {
  let (_, feature) = only_feature(tile, "multipoint")
  ensure(feature.geometry_type == @model.GeomType::Point, "multipoint type")
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
  )
  ensure(
    geometry.paths[0].points == [point(1, 2), point(20, 30), point(40, 8)],
    "multipoint coordinates",
  )
}

///|
fn verify_line(tile : @model.Tile) -> Unit raise {
  let (_, feature) = only_feature(tile, "line")
  ensure(feature.geometry_type == @model.GeomType::LineString, "line type")
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
  )
  ensure(geometry.paths.length() == 1, "line path count")
  ensure(
    geometry.paths[0].points == [point(0, 0), point(10, 5), point(30, 25)],
    "line coordinates",
  )
}

///|
fn verify_multiline(tile : @model.Tile) -> Unit raise {
  let (_, feature) = only_feature(tile, "multiline")
  ensure(feature.geometry_type == @model.GeomType::LineString, "multiline type")
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
  )
  ensure(geometry.paths.length() == 2, "multiline path count")
  ensure(
    geometry.paths[0].points == [point(2, 2), point(4, 8)],
    "multiline first path",
  )
  ensure(
    geometry.paths[1].points == [point(100, 80), point(90, 70), point(120, 60)],
    "multiline second path",
  )
}

///|
fn verify_polygon(tile : @model.Tile) -> Unit raise {
  let (_, feature) = only_feature(tile, "polygon")
  ensure(feature.geometry_type == @model.GeomType::Polygon, "polygon type")
  let geometry = @geometry.decode_geometry(
    feature.geometry_type,
    feature.geometry,
  )
  ensure(geometry.paths.length() == 2, "polygon ring count")
  ensure(geometry.paths[0].closed, "polygon outer ring closure")
  ensure(geometry.paths[1].closed, "polygon inner ring closure")
  ensure(geometry.paths[0].points.length() == 4, "polygon outer vertices")
  ensure(geometry.paths[1].points.length() == 4, "polygon inner vertices")
}

///|
fn verify_attributes(tile : @model.Tile) -> Unit raise {
  let (layer, feature) = only_feature(tile, "attributes")
  ensure(layer.extent == 512, "custom extent")
  ensure(feature.id == Some(206UL), "attributes id")
  ensure(
    layer.property(feature, "string") ==
    Some(@model.MvtValue::StringValue("MoonMVT")),
    "string value",
  )
  ensure(
    layer.property(feature, "bool") == Some(@model.MvtValue::BoolValue(false)),
    "bool value",
  )
  ensure(
    layer.property(feature, "positive").map(value => value.display()) ==
    Some("4"),
    "positive integer value",
  )
  ensure(
    layer.property(feature, "negative").map(value => value.display()) ==
    Some("-5"),
    "negative integer value",
  )
  ensure(
    layer.property(feature, "double").map(value => value.display()) ==
    Some("1.5"),
    "double value",
  )
}
