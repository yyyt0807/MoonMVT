# Third-party notices and reference material

MoonMVT is an original MoonBit implementation. No source code from the projects
listed below is included in this repository.

## Mapbox Vector Tile specification

- Project: Mapbox Vector Tile Specification
- URL: <https://github.com/mapbox/vector-tile-spec>
- Version used: 2.1
- Documentation license: Creative Commons Attribution 3.0 United States
- Referenced scope: field numbers, enum values, geometry command grammar,
  polygon winding requirements, and the published `vector_tile.proto` schema.

The specification name is used only to describe compatibility. Mapbox is a
trademark of its respective owner; this project is not affiliated with or
endorsed by Mapbox.

## Generated and sample data

All coordinate fixtures and example feature names in this repository were
written for MoonMVT. The repository contains no third-party map tiles, road
networks, personal location traces, or restricted geographic datasets.

Before adding an external `.mvt` or `.pbf` fixture, contributors must record its
origin, version, license, and redistribution permission in this file.

## Interoperability fixture generator

- Project: `mapbox-vector-tile`
- URL: <https://github.com/tilezen/mapbox-vector-tile>
- Version used: 2.2.0
- License: MIT
- Referenced scope: one 55-byte tile generated from an original, minimal point
  feature on 2026-09-10 and stored inline in `codec/decode_test.mbt`.

No source code, documentation text, geographic data, or bundled fixture from the
Python project is copied. The generated tile contains only the synthetic names
`interop`, `name`, `ok`, and `python`, plus the coordinate `(7, 11)`.
