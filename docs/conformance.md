# MVT 2.1 conformance

Reference: [Mapbox Vector Tile Specification 2.1](https://github.com/mapbox/vector-tile-spec/tree/master/2.1).

## Supported

- `Tile.layers` field 3;
- Layer `name`, `features`, `keys`, `values`, `extent`, and `version`;
- Feature `id`, packed `tags`, `type`, and packed `geometry`;
- String, float, double, int64, uint64, sint64, and bool values;
- UNKNOWN, POINT, LINESTRING, and POLYGON geometry types;
- MoveTo, LineTo, ClosePath, delta coordinates, and zigzag parameters;
- multiple layers, multipoints, multi-lines, polygon holes, and multipolygons;
- coordinates outside `[0, extent]` for buffered tiles;
- unknown field skipping for protobuf forward compatibility.

## Deliberately strict

MoonMVT rejects:

- non-minimal varint encodings;
- protobuf groups and unknown wire type numbers;
- duplicate singular fields;
- Value messages containing zero or multiple known variants;
- boolean values other than varint 0 or 1;
- layer versions other than 2;
- missing required Layer name or version;
- duplicate layer names in one Tile;
- odd tags or dictionary indexes outside their arrays;
- invalid command ids, zero counts, truncated coordinate pairs, and overflow;
- point/line/polygon command sequences that violate their declared type;
- degenerate or incorrectly ordered polygon rings.

The strict profile makes malformed input failures predictable. If broad
compatibility with a known producer requires accepting a noncanonical case, it
should be introduced as an explicit decode policy rather than a silent change.

## Unknown fields

Unknown fields are skipped subject to a configured count limit. They are not
stored in the typed model and therefore disappear after re-encoding. This is why
`canonicalize` may change a logically valid external document.

## Interoperability verification

On 2026-09-10, Python `mapbox-vector-tile` 2.2.0 decoded MoonMVT's fixed point
golden vector as layer `x`, feature ID `1`, extent `4096`, and point `(1, 2)`.
The same independent implementation generated a point tile with typed string
and boolean properties; that 55-byte document is retained as a MoonMVT decoder
regression fixture. Its provenance and MIT license are recorded in
`THIRD_PARTY_NOTICES.md`.

Before each release, repeat both directions with the release candidate. Self
round trips remain necessary but are not sufficient interoperability evidence.
