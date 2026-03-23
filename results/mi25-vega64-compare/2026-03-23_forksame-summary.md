# MI25 vs Vega64 ROCm Repeat Summary (fork/fork aligned)

Date: 2026-03-23

## Conditions

- Binary family: MI25=`/home/limonene/ROCm-project/ollama-src/ollama`, Vega64=`/tmp/ollama-fork-compare/ollama` (copied from same fork)
- Vega64 backend libs: `/tmp/ollama-fork-compare/build-gfx900/lib/ollama`
- Model: `tinyllama:latest`
- Options: `num_predict=128`, `temperature=0.1`, `num_thread=16`, `keep_alive=10m`, `stream=false`
- Warm-up: 1 run each excluded; Measured runs: 5 + 5 (alternating)

## eval_tps

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 208.45 | 224.33 | 216.98 | 219.45 | 6.51 |
| Vega64/ROCm | 214.66 | 248.77 | 241.58 | 248.50 | 13.47 |

## load_duration (seconds)

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.0900 | 0.1602 | 0.1291 | 0.1271 | 0.0241 |
| Vega64/ROCm | 0.0888 | 0.1014 | 0.0942 | 0.0928 | 0.0043 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.132x**

## Evidence files

- `mi25_rocm_forksame_repeat_20260323_202017.jsonl`
- `vega64_rocm_forksame_repeat_20260323_202017.jsonl`
