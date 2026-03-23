# MI25 vs Vega64 ROCm Repeat Summary (fork/fork aligned, num_thread=4, 20 runs)

Date: 2026-03-23

## Conditions

- Endpoints: MI25 127.0.0.1:11434, Vega64 127.0.0.1:22445 (SSH tunnel to copied fork service)
- Options: num_predict=128, temperature=0.1, num_thread=4, keep_alive=10m, stream=false
- Warm-up: 1 run each excluded; Measured runs: 20 + 20 (alternating)

## eval_tps

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 201.46 | 209.39 | 215.24 | 217.54 | 217.76 | 214.11 | 4.17 |
| Vega64/ROCm | 218.85 | 240.81 | 243.61 | 244.39 | 244.49 | 241.88 | 5.82 |

## load_duration (seconds)

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.0829 | 0.0982 | 0.1345 | 0.1501 | 0.1600 | 0.1287 | 0.0211 |
| Vega64/ROCm | 0.0755 | 0.0794 | 0.0965 | 0.0981 | 0.1019 | 0.0935 | 0.0070 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.132x**

## Evidence files

- `mi25_rocm_forksame_thread4_20run_20260323_203048.jsonl`
- `vega64_rocm_forksame_thread4_20run_20260323_203048.jsonl`
