# Interoperability and quantitative acceptance

MoonMVT is compared against two independently maintained MVT implementations:

- [`mapbox-vector-tile` 2.2.0](https://github.com/tilezen/mapbox-vector-tile), a mature Python encoder and decoder under MIT;
- [`@mapbox/vector-tile` 3.0.0](https://github.com/mapbox/vector-tile-js), Mapbox's JavaScript decoder under BSD-3-Clause, with `pbf` 5.1.2.

The binary format reference is the public [Mapbox Vector Tile Specification 2.1](https://github.com/mapbox/vector-tile-spec/tree/master/2.1). Interoperability is judged by decoded semantics, not byte equality: conforming Protobuf writers may use different field and dictionary order.

## Reproducible matrix

| Producer | Consumer | Cases | Assertions | Required result |
|---|---|---:|---:|---:|
| MoonMVT | `mapbox-vector-tile` | 6 | 25 | 6/6 (100%) |
| `mapbox-vector-tile` | MoonMVT | 6 | 52 | 6/6 (100%) |
| MoonMVT | `@mapbox/vector-tile` | 6 | 29 | 6/6 (100%) |
| **Total** | | **18** | **106** | **18/18 (100%)** |

Each producer creates its bytes during the test. The six cases cover Point with ID and properties, MultiPoint, LineString, MultiLineString, Polygon with a hole, and all seven MVT value encodings with a custom extent. Checks cover layer name/version/extent, feature count/ID/type, properties, geometry coordinates or bounding boxes, paths, ring closure, and integer/float/bool/string values.

Run the same gates locally:

```text
python -m pip install -r tools/interop/requirements.txt
python tools/interop/run.py
npm ci --prefix tools/interop
npm run --prefix tools/interop check
```

Passing means every vector is decoded without error and every semantic assertion matches. Any exception, missing case, mismatched value, geometry, ID, extent, or non-zero process exit fails CI. The matrix deliberately does not claim byte-for-byte equality or compare GeoJSON projection, clipping, simplification, rendering, or storage, which are outside MoonMVT's boundary.

## Capability comparison

| Capability | MoonMVT 0.1.1 | `mapbox-vector-tile` 2.2.0 | `@mapbox/vector-tile` 3.0.0 |
|---|---|---|---|
| MVT decoding | Yes | Yes | Yes |
| MVT encoding | Yes | Yes | No |
| Typed tile-local builder | Yes | GeoJSON/WKT/Shapely input | No |
| Explicit decode resource budgets | Yes | Not used as benchmark claim | Not used as benchmark claim |
| MoonBit wasm/wasm-gc/js/native checks | Yes | Not applicable | Not applicable |

This table defines product boundaries; it is not a claim that MoonMVT replaces projection, GeoJSON conversion, GIS repair, rendering, or the broader ecosystems of either comparison project.
