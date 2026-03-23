# Binary Alignment Attempt Report (MI25 vs Vega64)

Date: 2026-03-23 (Asia/Tokyo)
Directory: `/home/limonene/ROCm-project/vega_investigations/results/mi25-vega64-compare`

## Goal

Reduce stack confounders by aligning binary family across MI25 and Vega64 before repeating benchmark.

## Attempt A: both nodes with `/usr/local/bin/ollama`

- MI25 temporary service: `/usr/local/bin/ollama serve` (port `21434`)
- Vega64 temporary service: `/usr/local/bin/ollama serve` (port `21435`)
- Options: `num_thread=16`, `keep_alive=10m`

### Result

Both nodes fell back to **CPU backend**, so this path is invalid for ROCm comparison.

Evidence:

- MI25 log: `mi25_usrlocal_rocm_21434_20260323_193323.log`
  - `load_backend: loaded CPU backend from /usr/local/lib/ollama/libggml-cpu-haswell.so`
  - `load request ... GPULayers:[]`
- Vega64 log (copied): `vega64_usrlocal_rocm_21435_20260323_193323.log`
  - `inference compute ... id=cpu library=cpu`

## Attempt B: MI25 fork binary on Vega64 (`fork/fork` alignment)

- Copied to abyss:
  - `/tmp/ollama-fork-gfx900-test/ollama` (from MI25 fork)
  - `/tmp/ollama-fork-gfx900-test/lib/ollama/*` (from `build-gfx900/lib/ollama`)
- Started temporary service on abyss port `21437`

### Result

Still **CPU backend** on Vega64.

Evidence:

- abyss log (copied): `vega64_forkcopy_rocm_21437_20260323.log`
  - `inference compute ... id=cpu library=cpu`

## Attempt C: `/usr/bin/ollama` family on MI25

- Copied abyss `/usr/bin/ollama` to MI25 `/tmp/ollama_usrbin_from_abyss`
- Direct execution test on MI25

### Result

Cannot run due glibc mismatch.

Evidence:

- `/tmp/ollama_usrbin_from_abyss: /lib/x86_64-linux-gnu/libm.so.6: version 'GLIBC_2.43' not found`

## Attempt D: fork/fork retry with relative `build-gfx900` layout (success)

- Vega64 side staging:
  - binary: `/tmp/ollama-fork-compare/ollama` (copied fork binary)
  - libs: `/tmp/ollama-fork-compare/build-gfx900/lib/ollama`
  - env: `OLLAMA_LIBRARY_PATH=/tmp/ollama-fork-compare/build-gfx900/lib/ollama`
  - service port: `21445`
- MI25 side: existing fork service (`/home/limonene/ROCm-project/ollama-src/ollama`, port `11434`)
- Benchmark condition: `num_thread=16`, `keep_alive=10m`, warm-up 1 run excluded, 5 runs each

### Result

ROCm path became valid on both sides with fork-family comparison.

Evidence:

- Vega64 log: `vega64_forksame_20260323_202017.log`
  - `inference compute ... library=ROCm compute=gfx900`
  - `load_backend: loaded ROCm backend from /tmp/ollama-fork-compare/build-gfx900/lib/ollama/libggml-hip.so`
  - `load request ... NumThreads:16 GPULayers:23`
- MI25 log: `mi25_forksame_20260323_202017.journal.log`
  - `library=ROCm`
  - `load request ... NumThreads:16 GPULayers:23`
- Summary: `2026-03-23_forksame-summary.md`
  - median ratio (Vega64/MI25): `1.132x`

## Practical conclusion (updated)

- Binary-family alignment was not possible with `/usr/local` or `/usr/bin` direct unification.
- However, fork binary staging with the expected `build-gfx900` library layout enabled a practical `fork/fork` ROCm comparison path.
- Current strongest chain for interpretation:
  1. baseline ROCm-vs-ROCm: `1.266x`
  2. `NumThreads=16` + `keep_alive=10m`: `1.098x`
  3. fork/fork retry (ROCm valid both, 5 runs): `1.132x`
  4. fork/fork extended run (20 runs): `1.111x`
