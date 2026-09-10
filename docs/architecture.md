# Architecture

MoonMVT follows a one-way dependency structure. `error` and `model` form the
base; `limits`, `wire`, and `geometry` build on them; `codec` owns document
encoding; `builder` and `query` expose application workflows. The package graph
contains no cycle. `query` depends on `builder` only to rebuild compact property
dictionaries after filtering.

## Wire boundary

`wire.Reader` owns a cursor and an exclusive end offset for one protobuf
message. A subreader shares immutable source bytes but cannot advance into its
parent's suffix. Every length is checked before cursor movement. Groups are
rejected because MVT does not use them.

The package is intentionally not a general protobuf implementation. It has no
descriptors, reflection, schemas, maps, extensions, groups, services, or code
generation. This keeps the public project identity tied to MVT rather than to a
second serialization framework.

## Typed model

The codec model retains MVT's ordered layers, features, key dictionary, value
dictionary, tag index pairs, and geometry words. Retaining these details allows
exact logical round trips and stable encoding.

Applications should normally use `LayerBuilder` and resolved `Property` values.
Raw indexes and command words remain available for advanced interoperation and
for preserving externally decoded documents.

## Geometry boundary

Geometry encoders receive tile-local `Int` coordinates. Delta arithmetic is
performed in `Int64`, then checked against the signed 32-bit range required by
zigzag-encoded uint32 parameters. Decoding likewise accumulates in `Int64` and
rejects overflow before converting to `Int`.

Polygon paths omit a repeated closing coordinate. Closure is represented by the
MVT `ClosePath` command. Ring orientation is checked using signed shoelace area
in the y-down tile coordinate system.

## Deterministic construction

The builder interns keys and typed values by first appearance. Floating values
use exact IEEE payload bits for dictionary identity, so repeated NaNs are
handled deterministically. Encoding writes known fields in ascending field
number while preserving observable array order.

## Complexity

- Wire encoding and decoding: `O(B)` time and `O(B)` decoded/output storage for
  `B` bytes.
- Geometry expansion: `O(P)` time and `O(P)` output for `P` coordinates.
- Property resolution: `O(T)` for `T` tag indexes.
- Current dictionary interning: `O(K² + V²)` worst case per layer because it
  uses stable linear search. Typical MVT dictionaries are small; avoiding hash
  requirements also permits exact typed floating identity across all targets.
- Filtering: `O(F + P + T)` excluding interning cost, for features, points, and
  tags processed.

If real-world benchmarks show very large dictionaries, a stable hash index can
be added internally without changing public APIs.

