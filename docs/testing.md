# Testing strategy

MoonMVT uses package-local white-box tests plus black-box integration tests. The suite runs unchanged on wasm, wasm-gc, JavaScript and Native backends.

The test matrix covers:

- canonical varint, zigzag and fixed-width wire operations;
- truncated, overflowing, non-canonical and wrong-wire-type inputs;
- resource limits for documents, nested messages, dictionaries, tags and geometry;
- every MVT geometry family, delta coordinates and polygon winding;
- deterministic encode/decode round trips and a fixed schema golden vector;
- builder dictionary interning, duplicate rejection and transactional failure;
- property, geometry and bounds filters with dictionary compaction;
- public-API workflows equivalent to the README examples.

Run the strict local gate with:

```text
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/build_tile
moon run examples/filter_tile
python -m pip install -r tools/interop/requirements.txt
python tools/interop/run.py
npm ci --prefix tools/interop
npm run --prefix tools/interop check
moon run --release --target native benchmarks/codec_bench
```

For a release candidate, also generate interfaces with `moon info --target all` and confirm the working tree remains clean. The independent release gate requires 18/18 runtime-generated vectors and 106/106 semantic assertions, plus the documented fixed-workload performance floor. Independent interoperability is not inferred from MoonMVT decoding its own output.
