# MI25 vs Vega64 ROCm Repeat Summary (tinyllama)

Date: 2026-03-23T18:42:02+09:00

## Conditions

- Model: `tinyllama:latest`
- Prompt: `Write a concise 120-word note about validating legacy GPUs for local LLM inference.`
- Options: `num_predict=128`, `temperature=0.1`, `keep_alive=0s`, `stream=false`
- Runs: MI25=5, Vega64=5
- Endpoints: MI25 `127.0.0.1:11434` (ROCm), Vega64 `127.0.0.1:11435` (ROCm)

## eval_tps

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 184.92 | 210.94 | 198.10 | 201.86 | 10.69 |
| Vega64/ROCm | 236.73 | 258.33 | 252.67 | 255.55 | 8.07 |

## total_duration (seconds)

| Host | min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 1.7430 | 2.0202 | 1.8370 | 1.8281 | 0.0983 |
| Vega64/ROCm | 1.4399 | 1.5303 | 1.4947 | 1.4918 | 0.0325 |

## Quick take

- Median `eval_tps` ratio (Vega64/ROCm ÷ MI25/ROCm): **1.266x**.
- Both sides were ROCm path, but host and stack are different; treat as operational benchmark evidence.

## Important confounders (confirmed)

- MI25 side load request shows `NumThreads:4`.
- Vega64 ROCm side load request shows `NumThreads:16`.
- MI25 uses local forked binary/service (`/home/limonene/ROCm-project/ollama-src/ollama`) with local library-path injection.
- Vega64 uses distro ROCm service wrapper (`/usr/bin/ollama` via `ollama-rocm-serve`).
- Therefore this gap is better interpreted as *stack/configuration difference* first, not raw silicon-only difference.

## Evidence files

- `mi25_rocm_repeat_20260323_184113.jsonl`
- `vega64_rocm_repeat_20260323_184113.jsonl`
