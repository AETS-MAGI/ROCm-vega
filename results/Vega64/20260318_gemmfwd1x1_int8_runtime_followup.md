# 2026-03-18 GemmFwd1x1_0_1_int8 runtime follow-up

## 1. 目的

`dp4a_alternative_path.md` で static candidate として整理した
`GemmFwd1x1_0_1_int8` が、gfx900 (Vega64) 実機で
どこまで選択 / 実行されるかを確認する。

---

## 2. 環境

- GPU: Vega64 (`gfx900`)
- ROCm: `7.2.26043`
- MIOpen Driver: `3.5.1`
- MIOpen runtime log 表示:
  `MIOpen version 3.5.1.5b515cf1bca-dirty`

---

## 3. 実行コマンド

### 3.1 自然選択

```bash
bash run_vega_path_case.sh \
  vega64_int8_gemmcand_nat_1x1_n32_c64_k64_20260318 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1
```

### 3.2 search 有効化

```bash
bash run_vega_path_case.sh \
  vega64_int8_gemmcand_search_1x1_n32_c64_k64_20260318 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -s 1
```

### 3.3 symbolic solver 強制

```bash
bash run_vega_path_case.sh \
  vega64_int8_gemmcand_force_1x1_n32_c64_k64_20260318 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 \
  -S GemmFwd1x1_0_1_int8
```

### 3.4 only-solver search

```bash
MIOPEN_DEBUG_FIND_ONLY_SOLVER=GemmFwd1x1_0_1_int8 \
MIOPEN_FIND_ENFORCE=SEARCH_DB_UPDATE \
bash run_vega_path_case.sh \
  vega64_int8_gemmcand_onlysolver_search_1x1_n32_c64_k64_20260318 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -s 1
```

---

## 4. 観測結果

### 4.1 自然選択

Fact:

- `Solution: 85/ConvDirectNaiveConvFwd`
- 実行 kernel:
  `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t`
- 実行は成功

Interpretation:

- 少なくともこの 1x1 INT8 条件では、
  natural path は `GemmFwd1x1_0_1_int8` へは入らず、
  `ConvDirectNaiveConvFwd` に留まる。

### 4.2 search 有効化

Fact:

- `-s 1` を付けても `Solution: 85/ConvDirectNaiveConvFwd`
- log 上で `GemmFwd1x1_0_1_int8` が best solution としては現れない

Interpretation:

- search を有効にしても、この条件では
  `GemmFwd1x1_0_1_int8` が可視の candidate には上がっていない。

### 4.3 symbolic solver 強制

Fact:

- `Warning: Solution id (89) is not reported by the library. Trying it anyway...`
- `Info [GetForwardSolutionWorkspaceSize] solver_id = GemmFwd1x1_0_1_int8`
- `The supplied solution id: GemmFwd1x1_0_1_int8 is not applicable to the current problem`
- `RunForwardGPU() FAILED, rc = 0x3`

Interpretation:

- symbolic solver 名から solution id `89` への解決自体は行われる。
- ただし、その後の forward solution applicability 判定で止まる。

### 4.4 only-solver search

Fact:

- `Info [GetEnvFindOnlySolverImpl] 89`
- `Info2 [GetWorkspaceSizes] GemmFwd1x1_0_1_int8: Not applicable`
- `Info2 [SearchForAllSolutions] GemmFwd1x1_0_1_int8: Not applicable`
- `No suitable algorithm was found to execute the required convolution`
- `RunForwardGPU() FAILED, rc = 0x7`

Interpretation:

- current installed runtime では、
  `GemmFwd1x1_0_1_int8` は workspace-size evaluation と search-phase の両方で
  `Not applicable` と扱われる。

---

## 5. 根拠リンク（ログ / コード）

### ログ

- `../../vega_path_check_logs/vega64_int8_gemmcand_nat_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_gemmcand_search_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_gemmcand_force_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_gemmcand_onlysolver_search_1x1_n32_c64_k64_20260318.log`

### コード

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/solver/gemm.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/gemm_v2.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/find_controls.cpp`

---

## 6. 判定

`confirmed`

少なくとも current ROCm 7.2 / MIOpen 3.5.1 の Vega64 実機と
今回の `NCHW + INT8 + 1x1 + group=1` 条件では、
`GemmFwd1x1_0_1_int8` は practical route として成立していない。

ここで confirmed なのは、

- source-level candidate が存在すること
- natural selection は `ConvDirectNaiveConvFwd` に留まること
- forced-solution / only-solver search の両方で `Not applicable` が観測されたこと

である。

`Not applicable` の主因そのものは未確定である。

---

## 7. 次アクション

1. `GemmFwd1x1_0_1_int8` の追加 applicability 条件を source / log から切り分ける
2. `CallGemmMIOpenTensile` / rocBLAS 側の gfx900 INT8 catalog / shipped artifact を確認する
3. 必要なら INT8 専用 public page を切るが、現時点では `solver-trace.html` への追記で十分
