# MoonBit ecosystem comparison

Checked on 2026-09-10 through the official mooncakes.io server-side search API:

```text
GET https://mooncakes.io/api/v0/search?kw=<term>&limit=20
```

Exact searches for `Mapbox Vector Tile`, `MVT`, `PBF`, and `protobuf geometry`
returned no MVT codec or builder module. Searches for broader terms such as
`vector tile`, `map tile`, `tile encoder`, and `web map tile` were also reviewed
to catch packages whose names omit MVT.

## Nearest published projects

### NBB2006/routeweave

`routeweave` handles GPS route points, encoded polyline, GeoJSON export, route
metrics, Douglas-Peucker simplification, Web Mercator tile coverage, sampling,
and route analysis. MoonMVT does none of those tasks. It consumes tile-local
integer features and implements the MVT binary document, property dictionaries,
and geometry command stream.

### Mostan-303/moonbit-cog

`moonbit-cog` targets Cloud-Optimized GeoTIFF and multispectral raster data.
MoonMVT handles vector features and does not decode imagery, TIFF, overviews, or
remote raster ranges.

### General protobuf packages

Protobuf implementations solve a general schema/runtime problem. MoonMVT has an
internal, deliberately incomplete wire layer and no IDL, reflection, descriptors,
services, or generated types. Its public value is MVT semantics and safe typed
construction rather than general serialization.

## Difference from the author's earlier projects

MoonMVT is not another offline audit CLI or protocol decision engine. Its primary
workflow is a reusable in-process builder and editable typed model consumed by
mapping applications. It introduces dictionary interning, spatial feature
models, geometry command construction, ring orientation, and cross-target map
data workflows absent from the author's earlier BDD, external sorting, HTTP
cache, IPFIX, simulation, MIME, OCI, and resumable upload projects.

## Recheck policy

mooncakes.io changes continuously. Before submitting the proposal and again
before publishing, repeat all exact and broad searches. If a new MVT package has
appeared, compare its API, MVT coverage, maintenance state, target support, and
construction workflow, then update this document and the proposal honestly.

