# Changelog

All notable changes to MoonMVT are documented here.

## 0.1.1 - 2026-09-13

### Added

- Reproducible bidirectional interoperability against Python
  `mapbox-vector-tile` 2.2.0 and decode verification with Mapbox
  `@mapbox/vector-tile` 3.0.0.
- Quantitative 18-vector/106-assertion acceptance matrix and a fixed-workload
  Native release performance regression gate.
- Documented industry comparison, explicit pass/fail rules, and five-run
  benchmark baseline.

## 0.1.0 - 2026-09-10

### Added

- Bounded protobuf wire reader and deterministic writer for MVT fields.
- Typed MVT Tile, Layer, Feature, Value, and geometry models.
- Point, multi-line, and polygon command encoders and strict decoders.
- Ring winding, geometry bounds, path statistics, and structural validation.
- Deterministic tile codec with canonicalization support.
- Layer and tile builders with stable property dictionary interning.
- Feature property, geometry type, and tile-coordinate bounds filters.
- Cross-target tests and two runnable examples.
