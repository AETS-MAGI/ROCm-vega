# 2026-03-18 MIOpen INT8 solution query probe

## 1. 目的

`GemmFwd1x1_0_1_int8` が Vega64 / gfx900 の current installed MIOpen で
`not applicable` になる境界を、`MIOpenDriver convint8` から一段切り離して確認する。

今回の関心は、

- `x=int8, w=int8, y=int8`
- `x=int8, w=int8, y=int32`

で `miopenConvolutionForwardGetSolutionCount()` /
`miopenConvolutionForwardGetSolution()` /
`miopenConvolutionForwardGetSolutionWorkspaceSize()` の結果がどう変わるかである。

---

## 2. 実施方法

`tmp/int8_solution_probe.cpp` を作成し、
`hipcc` で小さな query-only probe をビルドした。

実行コマンド:

```bash
/opt/rocm/bin/hipcc -std=c++17 -O2 \
  tmp/int8_solution_probe.cpp \
  -o tmp/int8_solution_probe \
  -lMIOpen

./tmp/int8_solution_probe \
  > vega_path_check_logs/vega64_miopen_int8_solution_probe_20260318.log 2>&1
```

probe は GPU buffer を確保せず、
descriptor と convolution descriptor だけを作成して
forward immediate solution query API を呼ぶ。

条件:

- `xDesc = int8, NCHW = 32x64x56x56`
- `wDesc = int8, NCHW = 64x64x1x1`
- `conv = pad 0, stride 1, dilation 1, group 1`
- 比較対象:
  - `yDesc = int8, 32x64x56x56`
  - `yDesc = int32, 32x64x56x56`

---

## 3. 観測結果

### 3.1 `yDesc = int8`

Fact:

- `GetSolutionCount = 1`
- `GetSolution` の返却は `id=85` のみ
- `Workspace(id=85) = success, ws=0`
- `Workspace(id=89) = miopenStatusBadParm (3)`

Interpretation:

- 少なくとも `y=int8` の descriptor 条件では、
  `GemmFwd1x1_0_1_int8` (`id=89`) は current installed library 上で
  applicable solution として露出しない。

### 3.2 `yDesc = int32`

Fact:

- `GetSolutionCount = 2`
- `GetSolution` は少なくとも次を返す
  - `id=89`, `algo=0`, `ws=200704`
  - `id=85`, `algo=1`, `ws=0`
- `Workspace(id=89) = success, ws=200704`

Interpretation:

- 同じ installed library でも、
  `y=int32` にすると `GemmFwd1x1_0_1_int8` は
  applicable solution として露出する。
- したがって、今回の `convint8` で観測された
  `GemmFwd1x1_0_1_int8: Not applicable`
  は、少なくとも `solver/backend 自体が存在しない` こととは同一ではない。

### 3.3 `MIOpenDriver convint8` との対照

Fact:

- 既存の `MIOpenDriver convint8` runtime log では、
  output tensor descriptor の `dataType = 3` が記録されている。
- `miopenDataType_t` の enum では `3 = miopenInt8`, `2 = miopenInt32` である。
- 一方、current public `driver/conv_driver.hpp` では、
  `data_type == miopenInt8 || miopenInt8x4` のとき
  output tensor は `miopenInt32` に設定される実装になっている。

Interpretation:

- 少なくとも観測上は、
  current public source tree の `conv_driver.hpp` と
  installed `MIOpenDriver convint8` の実行経路は一致していない。
- 今回の practical blockage は、
  `MIOpen convolution solver が存在しない` よりも、
  **driver / output-type path の差分**
  に強く寄っていると読むのが自然である。

---

## 4. 判定

`confirmed`

少なくとも current installed MIOpen では、

- `y=int8` では `GemmFwd1x1_0_1_int8` は露出しない
- `y=int32` では `GemmFwd1x1_0_1_int8` (`id=89`) が露出し、workspace query も通る

ことが query-level に確認できた。

ここで confirmed なのは、
`not applicable` 境界が solver existence の有無そのものではなく、
少なくとも descriptor / output-type 条件と結びついているという範囲である。

---

## 5. 根拠リンク

- `../../vega_path_check_logs/vega64_miopen_int8_solution_probe_20260318.log`
- `../../vega_path_check_logs/vega64_int8_gemmcand_force_1x1_n32_c64_k64_20260318.log`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/conv_driver.hpp`
- `/opt/rocm/include/miopen/miopen.h`

---

## 本文書が主張しないこと

- installed `MIOpenDriver` の内部実装差分の全容を特定したものではない
- current public source tree と installed binary の差分理由を断定するものではない
- `y=int32` なら常に gfx900 INT8 conv route が practical に成立すると主張するものではない
- 特定組織や個人への批判を目的とするものではない
