# ADR 0001: Keep the core in tile-local coordinates

## Status

Accepted

## Context

An MVT library can accept geographic coordinates and perform projection,
clipping, simplification, and tile selection, or it can accept tile-local
integer coordinates and focus on the MVT document itself. The first option is
convenient but creates a GIS pipeline whose policy choices are difficult to
reverse and whose scope overlaps existing MoonBit route and tile utilities.

## Decision

MoonMVT's core model and builders accept tile-local integer coordinates. The
project will not provide WGS84 projection, tile coverage, network retrieval,
map styling, or rendering in version 0.1.

## Consequences

Callers retain control over projection and clipping. The library can remain
portable across MoonBit targets and can test MVT geometry semantics without
floating-point or projection ambiguity. Applications that begin with longitude
and latitude need a separate preprocessing step.

