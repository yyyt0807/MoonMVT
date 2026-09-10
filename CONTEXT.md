# MoonMVT Domain Language

This glossary defines the project vocabulary. It intentionally contains no
implementation decisions.

## Tile

One Mapbox Vector Tile document containing zero or more named layers. A Tile
does not know its web-map zoom, column, row, projection, URL, or storage key.

## Layer

A named collection of Features that shares an extent and two dictionaries:
property keys and property values. Layer order is observable and preserved.

## Feature

One optional identifier, zero or more properties, one geometry type, and one
geometry command stream. A Feature belongs to exactly one Layer.

## Tile coordinate

An integer coordinate in a Layer's local coordinate space. MoonMVT does not
interpret a tile coordinate as longitude, latitude, or a projected world
coordinate.

## Extent

The nominal width and height of a Layer's local coordinate space. Coordinates
may lie outside the extent because buffered vector tiles are valid.

## Geometry command stream

The MVT sequence of MoveTo, LineTo, and ClosePath commands plus delta-encoded
coordinate parameters. It is not a general-purpose vector path language.

## Property

A Feature attribute represented to callers as a key and typed Value. Dictionary
indexes are an encoding detail and are not part of a Property's identity.

## Canonical encoding

The deterministic byte representation produced by MoonMVT for a given MoonMVT
model. Canonical encoding does not claim that every conforming external encoder
must produce identical bytes.

## Structural validity

Conformance of field shapes, references, command sequences, and configured
resource limits. Structural validity does not imply geographic correctness.

