# Reproducible codec baseline

The release benchmark builds one synthetic layer containing 1,000 point features. Each feature has an ID and two properties drawn from small repeated dictionaries. It then performs 100 deterministic encodes and 100 decodes, for 100,000 feature operations in each direction.

```text
moon run --release --target native benchmarks/codec_bench
```

## Acceptance thresholds

- deterministic output: all 100 encodes equal the warm-up bytes;
- encoded size: at most 25,000 bytes for the fixed 1,000-feature fixture;
- encode throughput: at least 10,000 features/second;
- decode throughput: at least 10,000 features/second;
- decoded feature count: exactly 100,000 across the 100 iterations.

The executable exits unsuccessfully if any threshold is missed. The throughput floors are intentionally conservative to reduce CI hardware variance while still detecting order-of-magnitude regressions.

## Recorded baseline

On 2026-09-13, MoonBit `0.1.20260827`, Native release target, Windows 10.0.19045, Intel Family 6 Model 165, five warm-cache runs produced:

| Metric | Median | Acceptance floor/ceiling | Margin |
|---|---:|---:|---:|
| Encoded fixture size | 19,916 bytes | ≤25,000 bytes | 20.3% below ceiling |
| Encode throughput | 396,825 features/s | ≥10,000 features/s | 39.7× floor |
| Decode throughput | 133,868 features/s | ≥10,000 features/s | 13.4× floor |

These numbers are a MoonMVT regression baseline, not a cross-language speed ranking. Python and JavaScript libraries expose different models and runtime costs, so the fair cross-tool contract here is semantic interoperability; performance is measured within MoonMVT with a fixed workload.
