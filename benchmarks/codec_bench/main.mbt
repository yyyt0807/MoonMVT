///|
const FEATURE_COUNT : Int = 1000

///|
const ITERATIONS : Int = 100

///|
const MIN_FEATURES_PER_SECOND : UInt64 = 10000UL

///|
const MAX_FIXTURE_BYTES : Int = 25000

///|
fn main {
  run() catch {
    error => abort("MoonMVT benchmark failed: \{error}")
  }
}

///|
fn build_fixture() -> @model.Tile raise {
  let layer = @builder.LayerBuilder::new("benchmark")
  for i in 0..<FEATURE_COUNT {
    layer.add_points(
      [@model.Point::new(i % 4096, i * 17 % 4096)],
      id=Some(i.to_uint64()),
      properties=[
        @builder.property(
          "class",
          @model.MvtValue::StringValue(if i % 2 == 0 { "even" } else { "odd" }),
        ),
        @builder.property(
          "rank",
          @model.MvtValue::IntValue((i % 20).to_int64()),
        ),
      ],
    )
  }
  let tile = @builder.TileBuilder::new()
  tile.add_built_layer(layer)
  tile.finish()
}

///|
fn rate(elapsed_ms : UInt64) -> UInt64 {
  let safe_ms = if elapsed_ms == 0UL { 1UL } else { elapsed_ms }
  FEATURE_COUNT.to_uint64() * ITERATIONS.to_uint64() * 1000UL / safe_ms
}

///|
fn run() -> Unit raise {
  let tile = build_fixture()
  let warmup = @codec.encode_tile(tile)
  ignore(@codec.decode_tile(warmup))

  let encode_start = @env.now()
  let mut bytes = warmup
  for _ in 0..<ITERATIONS {
    bytes = @codec.encode_tile(tile)
    if bytes != warmup {
      abort("deterministic encoding changed during the benchmark")
    }
  }
  let encode_ms = @env.now() - encode_start

  let decode_start = @env.now()
  let mut decoded_features = 0
  for _ in 0..<ITERATIONS {
    let decoded = @codec.decode_tile(bytes)
    decoded_features += decoded.layers[0].features.length()
  }
  let decode_ms = @env.now() - decode_start
  if decoded_features != FEATURE_COUNT * ITERATIONS {
    abort("benchmark decoded an unexpected feature count")
  }
  let encode_rate = rate(encode_ms)
  let decode_rate = rate(decode_ms)
  if bytes.length() > MAX_FIXTURE_BYTES {
    abort("encoded fixture exceeded 25000-byte acceptance ceiling")
  }
  if encode_rate < MIN_FEATURES_PER_SECOND {
    abort("encode throughput fell below 10000 features/second")
  }
  if decode_rate < MIN_FEATURES_PER_SECOND {
    abort("decode throughput fell below 10000 features/second")
  }
  println("fixture_features=\{FEATURE_COUNT}")
  println("fixture_bytes=\{bytes.length()}")
  println("iterations=\{ITERATIONS}")
  println("encode_elapsed_ms=\{encode_ms}")
  println("decode_elapsed_ms=\{decode_ms}")
  println("encode_features_per_second=\{encode_rate}")
  println("decode_features_per_second=\{decode_rate}")
  println("acceptance_threshold=10000_features_per_second_and_25000_bytes")
  println("result=pass")
}
