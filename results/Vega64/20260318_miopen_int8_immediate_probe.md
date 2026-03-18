# 2026-03-18 MIOpen INT8 immediate probe

## 1. 目的

直前の query probe で、
`x=int8, w=int8, y=int32` の descriptor を直接与えると
`GemmFwd1x1_0_1_int8` (`solution_id = 89`) が visible solution として現れることを確認した。

このメモでは、その条件で

- `miopenConvolutionForwardCompileSolution()`
- `miopenConvolutionForwardImmediate()`

まで実際に成功するかを確認する。

---

## 2. 実施方法

`tmp/int8_immediate_probe.cpp` を作成し、
`hipcc` で小さな immediate probe をビルドした。

実行コマンド:

```bash
/opt/rocm/bin/hipcc -std=c++17 -O2 \
  tmp/int8_immediate_probe.cpp \
  -o tmp/int8_immediate_probe \
  -lMIOpen

./tmp/int8_immediate_probe \
  > vega_path_check_logs/vega64_miopen_int8_immediate_probe_20260318.log 2>&1
```

probe 条件:

- `xDesc = int8, NCHW = 32x64x56x56`
- `wDesc = int8, NCHW = 64x64x1x1`
- `yDesc = int32, NCHW = 32x64x56x56`
- `conv = pad 0, stride 1, dilation 1, group 1`
- `solution_id = 89`

入力と weight はすべて `1` で初期化した。
この条件なら、各出力要素の期待値は少なくとも単純和として `64` になる。

---

## 3. 観測結果

Fact:

- `solution_count = 2`
- `GetSolution()` は少なくとも次を返した
  - `solution[0] id=89 algo=0 ws=200704`
  - `solution[1] id=85 algo=1 ws=0`
- `workspace_size_89 = 200704`
- `compile_solution_89 = success`
- `forward_immediate_89 = success`
- 先頭出力は
  - `y_host[0] = 64`
  - `y_host[1] = 64`
  - `y_host[2] = 64`
  - `y_host[3] = 64`
- `first64_all_equal_64 = true`

Interpretation:

- 少なくとも current installed MIOpen library では、
  `x=int8, w=int8, y=int32` の direct immediate path において
  `GemmFwd1x1_0_1_int8` (`id=89`) は
  **query だけでなく compile / execute まで成立する**。
- したがって、今回の practical blockage は
  `gfx900 上で solver 89 が本質的に実行不能`
  という形では読めない。
- ここから少なくとも言えるのは、
  `MIOpenDriver convint8` tested case の閉塞点と、
  `same library への direct immediate path`
  を分けて扱う必要があるということである。

---

## 4. 判定

`confirmed`

少なくとも Vega64 / gfx900 の current installed MIOpen では、
`x=int8, w=int8, y=int32` descriptor を直接与える immediate path に限れば、
`GemmFwd1x1_0_1_int8` は compile / execute まで成功する。

---

## 5. 根拠リンク

- `../../vega_path_check_logs/vega64_miopen_int8_immediate_probe_20260318.log`
- `../../vega_path_check_logs/vega64_miopen_int8_solution_probe_20260318.log`
- `/opt/rocm/include/miopen/miopen.h`

---

## 本文書が主張しないこと

- `MIOpenDriver convint8` の default route がそのまま `id=89` に到達すると主張するものではない
- installed `MIOpenDriver` と current public `conv_driver.hpp` の差分理由を断定するものではない
- あらゆる INT8 shape / layout で `GemmFwd1x1_0_1_int8` が practical route になると主張するものではない
- 特定組織や個人への批判を目的とするものではない
