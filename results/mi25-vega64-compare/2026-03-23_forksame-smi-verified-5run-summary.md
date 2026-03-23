# MI25 vs Vega64 ROCm Summary (fork/fork, smi-verified, 5 runs)

Date: 2026-03-23

## Conditions

- Endpoints: MI25 127.0.0.1:11434, Vega64 127.0.0.1:22445
- Options: num_predict=128, temperature=0.1, num_thread=16, keep_alive=10m, stream=false
- Warm-up: 1 run each excluded; Measured runs: 5 + 5 (alternating)
- Concurrent GPU logs: MI25=/usr/bin/rocm-smi, Vega64=/opt/rocm/bin/rocm-smi

## eval_tps

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 216.19 | 217.47 | 221.72 | 221.88 | 221.91 | 220.21 | 2.22 |
| Vega64/ROCm | 233.25 | 236.99 | 243.31 | 244.71 | 244.77 | 241.71 | 4.31 |

## load_duration (seconds)

| Host | min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.0716 | 0.0909 | 0.1378 | 0.1501 | 0.1550 | 0.1254 | 0.0292 |
| Vega64/ROCm | 0.0671 | 0.0680 | 0.0844 | 0.0969 | 0.0992 | 0.0827 | 0.0127 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.097x**

## Evidence files

- `mi25_rocm_forksame_smi_verified_5run_20260323_203402.jsonl`
- `vega64_rocm_forksame_smi_verified_5run_20260323_203402.jsonl`
