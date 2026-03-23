# MI25 vs Vega64 Quick Compare (tinyllama)

Date: 2026-03-23 (Asia/Tokyo)

> Note: This file is a single-run snapshot. For repeat-run ROCm-vs-ROCm comparison, see `2026-03-23_rocm-repeat-summary.md`.

## Scope

- Target: quick sanity comparison for TODO item "MI25 と Vega64 の差"
- Method: one-shot `ollama /api/generate` on both hosts with identical request payload
- Source labels:
  - `[main-node confirmed]` local `hbmx-mi25` measurements
  - `[abyss-node confirmed]` remote `abyss-hbmx` measurements via `ssh abyss`

## Conditions

- Model: `tinyllama:latest`
- Prompt: `Write a concise 120-word note about validating legacy GPUs for local LLM inference.`
- Options: `num_predict=128`, `temperature=0.1`, `keep_alive=0s`, `stream=false`
- GPU sampling: `/opt/rocm/bin/rocm-smi --showuse --showmemuse --showpower --showtemp` every 1s while request is running

## Result (single-run)

| Host | GPU/Path | total_duration (s) | eval_duration (s) | eval_count | eval_tps | max GPU use (%) |
|---|---|---:|---:|---:|---:|---:|
| `hbmx-mi25` | MI25 / ROCm (`library=ROCm`) | 2.4187 | 0.6089 | 128 | 210.20 | 5 |
| `abyss-hbmx` | Vega64 / Vulkan (`library=Vulkan`) | 2.2791 | 0.5726 | 128 | 223.54 | 20 |
| `abyss-hbmx` | Vega64 / ROCm (`ollama-rocm`, port 11435) | 1.5609 | 0.5481 | 128 | 233.55 | 97 |

## Interpretation

- `[main-node confirmed]` / `[abyss-node confirmed]` this single run shows `Vega64/ROCm (11435)` > `Vega64/Vulkan (11434)` > `MI25/ROCm` in `eval_tps`.
- `[inference / unvalidated]` the host/backends differ (`MI25/ROCm` vs `Vega64/ROCm` vs `Vega64/Vulkan`), so this is not a strict architecture-only conclusion.
- `[inference / unvalidated]` single-run variance can be large; at least 3-5 repetitions and median comparison are recommended.

## Evidence files

- Local JSON: `mi25_tiny_bench_20260323_182115.json`
- Local rocm-smi log: `mi25_tiny_bench_20260323_182115.smi.log`
- Remote JSON: `vega64_tiny_bench_20260323_182144.json`
- Remote rocm-smi log: `vega64_tiny_bench_20260323_182144.smi.log`
- Remote ROCm JSON: `vega64_rocm_tiny_bench_20260323_183056.json`
- Remote ROCm rocm-smi log: `vega64_rocm_tiny_bench_20260323_183056.smi.log`
- Location: `/home/limonene/ROCm-project/vega_investigations/results/mi25-vega64-compare/`

## Notes

- `[abyss-node confirmed]` `abyss` has two parallel services:
  - `ollama.service` (Vulkan, `127.0.0.1:11434`)
  - `ollama-rocm.service` (ROCm, `127.0.0.1:11435`)
- `[main-node confirmed]` local MI25 service reports `library=ROCm` in recent journal lines.
