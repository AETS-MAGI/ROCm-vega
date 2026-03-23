# MI25 vs Vega64 ROCm Repeat Summary (fork/fork aligned, 20 runs)

Date: 2026-03-23

## Conditions

- Endpoints: MI25 `127.0.0.1:11434` (fork service), Vega64 `127.0.0.1:22445` via SSH tunnel to copied fork service
- Options: `num_predict=128`, `temperature=0.1`, `num_thread=16`, `keep_alive=10m`, `stream=false`
- Warm-up: 1 run each excluded; Measured runs: 20 + 20 (alternating)

## eval_tps

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 220.41 | 221.40 | 222.63 | 223.46 | 223.70 | 222.48 | 0.84 |
| Vega64/ROCm | 232.17 | 244.34 | 247.43 | 248.65 | 249.05 | 246.12 | 4.67 |

## load_duration (seconds)

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.0873 | 0.1098 | 0.1247 | 0.1510 | 0.1550 | 0.1276 | 0.0208 |
| Vega64/ROCm | 0.0691 | 0.0817 | 0.0889 | 0.0947 | 0.0978 | 0.0883 | 0.0064 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.111x**

## Evidence files

- `mi25_rocm_forksame20_repeat_20260323_202220.jsonl`
- `vega64_rocm_forksame20_repeat_20260323_202220.jsonl`
