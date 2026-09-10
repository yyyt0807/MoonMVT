# Contributing to MoonMVT

MoonMVT accepts focused fixes and additions within the MVT 2.1 tile-local data model. Projection, rendering, HTTP serving, storage containers and general Protocol Buffers support belong in separate projects.

Before opening a change, run:

```text
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/build_tile
moon run examples/filter_tile
moon info --target all
git diff --exit-code
```

New behavior needs tests for normal, boundary and malformed input. Parser changes must preserve resource limits and stable `MvtError::code()` categories. Encoding changes must preserve deterministic output unless an explicit compatibility decision records otherwise.

Use small, meaningful commits. Do not commit `_build`, `.mooncakes`, generated scratch data or copied third-party fixtures without a documented license and source in `THIRD_PARTY_NOTICES.md`.
