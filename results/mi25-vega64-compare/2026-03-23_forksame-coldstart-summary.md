# MI25 vs Vega64 ROCm Repeat Summary (fork/fork aligned, keep_alive=0s, num_thread=16, 10 runs)

Date: 2026-03-23

## Conditions

- Endpoints: MI25 127.0.0.1:11434, Vega64 127.0.0.1:22445 (SSH tunnel to copied fork service)
- Options: num_predict=128, temperature=0.1, num_thread=16, keep_alive=0s, stream=false
- Warm-up: none (cold-start intent); Measured runs: 10 + 10 (alternating)

## eval_tps

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 197.87 | 203.96 | 213.95 | 217.17 | 223.38 | 212.56 | 6.62 |
| Vega64/ROCm | 213.49 | 224.87 | 256.15 | 259.96 | 260.40 | 247.02 | 16.24 |

## load_duration (seconds)

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.9401 | 0.9562 | 0.9933 | 1.2562 | 1.6709 | 1.1098 | 0.2161 |
| Vega64/ROCm | 0.8207 | 0.8247 | 0.8465 | 0.9235 | 1.3402 | 0.8956 | 0.1494 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.197x**

## Evidence files

- `mi25_rocm_forksame_coldstart_10run_20260323_203158.jsonl`
- `vega64_rocm_forksame_coldstart_10run_20260323_203158.jsonl`
