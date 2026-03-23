# MI25 vs Vega64 ROCm Repeat Summary (NumThreads=16, keep_alive=10m)

Date: 2026-03-23

## Conditions

- Model: `tinyllama:latest`
- Prompt: `Write a concise 120-word note about validating legacy GPUs for local LLM inference.`
- Options: `num_predict=128`, `temperature=0.1`, `num_thread=16`, `keep_alive=10m`, `stream=false`
- Warm-up: 1 run each (excluded from measured set)
- Measured runs: MI25=5, Vega64=5 (alternating)
- Endpoints: MI25 `127.0.0.1:11434` (ROCm), Vega64 `abyss:11435` via SSH tunnel local `127.0.0.1:21135`

## eval_tps

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 199.99 | 222.48 | 216.11 | 221.55 | 8.51 |
| Vega64/ROCm | 243.19 | 243.79 | 243.42 | 243.37 | 0.20 |

## load_duration (seconds, measured runs)

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 0.0563 | 0.1329 | 0.0967 | 0.0986 | 0.0251 |
| Vega64/ROCm | 0.0867 | 0.0979 | 0.0925 | 0.0933 | 0.0043 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.098x**.
- With `keep_alive=10m` and warm-up excluded, load impact is reduced; compare decode-heavy behavior first.

## Evidence files

- `mi25_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `vega64_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
