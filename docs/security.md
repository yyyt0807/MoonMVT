# Security model

MoonMVT expects vector tiles to arrive from untrusted sources.

## Defenses

- Top-level and submessage lengths are bounded before allocation or slicing.
- Collection counts are bounded for layers, features, keys, values, tags,
  geometry words, strings, and unknown fields.
- Varints reject truncation, overflow, and overlong representations.
- Length-delimited readers cannot cross their parent message boundary.
- Geometry command counts are checked before parameter traversal.
- Delta coordinates accumulate in `Int64` and are range-checked before narrowing.
- Dictionary indexes are validated before property resolution.
- The library performs no network, filesystem, process, clock, or random access.

## Caller responsibilities

- Choose tighter `DecodeLimits` for memory-constrained or multi-tenant services.
- Apply application-specific authorization before exposing feature properties.
- Treat decoded text as untrusted when embedding it into HTML, SQL, logs, or
  another output language.
- Keep projection, clipping, and geographic topology validation in the upstream
  data pipeline; structural MVT validity is not geographic correctness.
- Avoid logging complete tiles when feature data may contain sensitive location
  information.

## Complexity and denial of service

Parsing is linear in accepted input size. Builder value/key interning and
distinct-point diagnostics use linear scans and can be quadratic for unusually
large dictionaries or paths. Input limits bound decoder exposure; applications
constructing very large tiles should benchmark their chosen limits.

## Reporting

Do not publish a suspected vulnerability with private data or an exploit tile.
Use the repository's private security reporting channel after the GitHub remote
is created.

