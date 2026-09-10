# ADR 0002: Ship a deterministic bidirectional codec

## Status

Accepted

## Context

A decoder-only package is useful for inspection, while an encoder-only package
supports tile production. Providing both increases work, but it enables
round-trip tests and supports the three target workflows: tile generation,
cross-target consumption, and fixture construction.

Protocol Buffers allows multiple byte representations for equivalent logical
messages. Unstable output makes caches and regression fixtures harder to use.

## Decision

Version 0.1 will decode MVT 2.1 into a typed model and encode that model using a
documented deterministic field order and stable dictionary order.

## Consequences

The project must test interoperability in both directions. Unknown fields may
be skipped while decoding, but they are not preserved when the typed model is
encoded again. Byte identity is promised only for repeated MoonMVT encoding of
the same MoonMVT model.

