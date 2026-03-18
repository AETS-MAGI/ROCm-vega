# 2026-03-18 MIOpen INT8 Find/Forward probe

## 1. 目的

直前までの観測で、

- direct solution query (`y=int32`) は `solution_id = 89` を返す
- direct immediate (`y=int32`) は `CompileSolution + ForwardImmediate` まで成功する
- installed `MIOpenDriver convint8 --out_cast_type fp32` はその代替にならない

ことを確認した。

このメモでは、
**standard の higher-level C API**

- `miopenFindConvolutionForwardAlgorithm()`
- `miopenConvolutionForward()`

でも同じ `y=int32` route が再現できるかを確認する。

---

## 2. 実施方法

`tmp/int8_find_forward_probe.cpp` を作成し、
installed MIOpen library に対して次を試した。

実行コマンド:

```bash
/opt/rocm/bin/hipcc -std=c++17 -O2 \
  tmp/int8_find_forward_probe.cpp \
  -o tmp/int8_find_forward_probe \
  -lMIOpen

MIOPEN_ENABLE_LOGGING=1 \
MIOPEN_ENABLE_LOGGING_CMD=1 \
MIOPEN_LOG_LEVEL=6 \
./tmp/int8_find_forward_probe \
  > vega_path_check_logs/vega64_miopen_int8_find_forward_probe_20260318.log 2>&1
```

probe 条件:

- `xDesc = int8, NCHW = 32x64x56x56`
- `wDesc = int8, NCHW = 64x64x1x1`
- `yDesc = int32, NCHW = 32x64x56x56`
- `conv = pad 0, stride 1, dilation 1, group 1`
- `alpha = 1`, `beta = 0`

以下を順に確認した。

1. `miopenConvolutionForwardGetWorkSpaceSize()`
2. `miopenFindConvolutionForwardAlgorithm(..., exhaustiveSearch=0)`
3. returned algo ごとの `miopenConvolutionForward()`
4. `miopenFindConvolutionForwardAlgorithm(..., exhaustiveSearch=1)`
5. returned algo ごとの `miopenConvolutionForward()`

---

## 3. 観測結果

Fact:

- `miopenConvolutionForwardGetWorkSpaceSize()` は
  `workspace_size = 200704` を返した。
- log 上では、
  problem key は
  `64-56-56-1x1-64-56-56-32-0x0-1x1-1x1-0-NCHW-INT8INT8INT32-F`
  と記録された。
- same log の `GetSolutionsFallback` では、
  `ConvDirectNaiveConvFwd` と `GemmFwd1x1_0_1_int8`
  の両方が visible candidate として現れた。
- `exhaustiveSearch = 0` の `miopenFindConvolutionForwardAlgorithm()` は成功し、
  `returned_algo_count = 2` を返した。
  - `perf[0] algo=GEMM time=2.35691 memory=200704`
  - `perf[1] algo=Direct time=4.61251 memory=0`
- 同条件の log では、
  `Find Ended` の後に
  `FW Chosen Algorithm: GemmFwd1x1_0_1_int8 , 200704, 2.35691`
  と記録された。
- `exhaustiveSearch = 0` 後の `miopenConvolutionForward()` は、
  - `algo=GEMM` で成功
  - `algo=Direct` でも成功
  した。
- どちらの forward 実行でも、
  先頭出力は `64` で一致し、
  `first64_all_equal_64 = true` だった。
- `exhaustiveSearch = 1` の `miopenFindConvolutionForwardAlgorithm()` も成功し、
  `returned_algo_count = 1`
  - `perf[0] algo=GEMM time=2.35691 memory=200704`
  を返した。
- 同条件の `miopenConvolutionForward(algo=GEMM)` も成功し、
  先頭出力は `64` で一致した。

Interpretation:

- 少なくとも current installed MIOpen では、
  **direct immediate だけでなく standard `Find/Forward` API でも**
  `y=int32` route は再現できる。
- したがって、今回の INT8 境界は
  `driver 以外の higher-level C API 全般が使えない`
  という形では読めない。
- ここから少なくとも言えるのは、
  current blockage は
  **`MIOpenDriver convint8` / driver-side descriptor assembly**
  側へさらに寄る、ということである。

---

## 4. 判定

`confirmed`

Vega64 / gfx900 の current installed MIOpen では、
`x=int8, w=int8, y=int32` descriptor を明示すれば、
standard `miopenFindConvolutionForwardAlgorithm()` /
`miopenConvolutionForward()` route でも
GEMM が返って実行まで成功する。

---

## 5. 根拠リンク

- `../../vega_path_check_logs/vega64_miopen_int8_find_forward_probe_20260318.log`
- `../../vega_path_check_logs/vega64_miopen_int8_immediate_probe_20260318.log`
- `../../vega_path_check_logs/vega64_miopen_int8_solution_probe_20260318.log`
- `/opt/rocm/include/miopen/miopen.h`

---

## 本文書が主張しないこと

- `MIOpenDriver convint8` の default route がそのまま `y=int32` へ切り替えられると主張するものではない
- installed driver と current public driver source の差分理由を断定するものではない
- あらゆる INT8 shape / layout で `miopenFindConvolutionForwardAlgorithm()` が GEMM を返すと一般化するものではない
- 特定組織や個人への批判を目的とするものではない
