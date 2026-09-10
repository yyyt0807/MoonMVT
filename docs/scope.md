# Version 0.1 scope

MoonMVT is a reusable Mapbox Vector Tile 2.1 codec and construction library.

Included:

- bounded decoding of Tile, Layer, Feature, Value, tags, and geometry commands;
- deterministic encoding of the supported MVT 2.1 model;
- typed point, line, and polygon builders using tile-local integer coordinates;
- stable property key/value interning;
- geometry command validation, bounds, and ring classification;
- APIs for filtering, selecting, and rebuilding decoded tiles;
- cross-target examples and tests.

Explicitly excluded:

- longitude/latitude projection and Web Mercator tile selection;
- GeoJSON parsing, spatial databases, map servers, HTTP, caches, and archives;
- clipping and simplification policy;
- raster tiles, Mapbox styles, labels, rendering, and user interaction;
- a general Protocol Buffers runtime or code generator;
- silent repair of malformed input.

