# 2026-03-18 MIOpenDriver INT8 out-cast follow-up

## 1. 目的

直前の direct query / direct immediate probe では、
same installed MIOpen library に対して
`x=int8, w=int8, y=int32` descriptor を直接与えると
`GemmFwd1x1_0_1_int8` (`solution_id = 89`) が visible かつ executable になることを確認した。

一方、installed `MIOpenDriver convint8 --help` には
legacy-style の

- `--in_cast_type`
- `--wei_cast_type`
- `--out_cast_type`

が見える。

このメモでは、
`MIOpenDriver convint8` 側で cast flag を使えば
direct `y=int32` path に近い route を再現できるかを確認する。

---

## 2. 事前確認

Fact:

- installed `MIOpenDriver convint8 --help` には
  `--in_cast_type`, `--wei_cast_type`, `--out_cast_type` が出る。
- legacy
  `00_legacy-repos/MIOpen/driver/conv_driver.hpp`
  では、
  `valid_cast_types = {"fp32", "fp16", "bf16", "fp8", "bf8"}`
  と定義されている。
- 同じ legacy file の `DataTypeFromShortString()` も、
  `fp32/fp16/bf16/fp8/bf8` だけを受理する。
- 同じ legacy file では、
  output tensor descriptor 自体は `data_type` で作られ、
  その後 `miopenSetTensorCastType(outputTensor, out_cast_type)` が任意で呼ばれる。
- current public standalone
  `MIOpen/driver/conv_driver.hpp`
  はこの cast flag 群を持たず、
  INT8 / INT8x4 時に output tensor の data type 自体を
  `miopenInt32` に設定する。

Interpretation:

- installed binary は help 文面の時点で legacy-style driver に近い。
- ただし、legacy-style cast flag は
  `int32` を直接受理する設計には見えない。
- source 上でも、
  `cast_type` と `output tensor dataType` は別概念として扱われている。

---

## 3. 実施方法

### 3.1 invalid token 確認

まず `--out_cast_type int32` を試した。

実行コマンド群:

```bash
bash run_vega_path_case.sh vega64_int8_outcast32_nat_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 --out_cast_type int32; ec=$?; echo __EXIT_CODE=$ec; exit 0'

bash run_vega_path_case.sh vega64_int8_outcast32_search_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -s 1 --out_cast_type int32; ec=$?; echo __EXIT_CODE=$ec; exit 0'

bash run_vega_path_case.sh vega64_int8_outcast32_force_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -S GemmFwd1x1_0_1_int8 --out_cast_type int32; ec=$?; echo __EXIT_CODE=$ec; exit 0'
```

### 3.2 accepted token 確認

次に source で valid token と読める `fp32` を試した。

実行コマンド群:

```bash
LOG_ROOT=vega_path_check_logs bash run_vega_path_case.sh vega64_int8_outcastfp32_nat_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 --out_cast_type fp32; ec=$?; echo __EXIT_CODE=$ec; exit 0'

LOG_ROOT=vega_path_check_logs bash run_vega_path_case.sh vega64_int8_outcastfp32_search_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -s 1 --out_cast_type fp32; ec=$?; echo __EXIT_CODE=$ec; exit 0'

LOG_ROOT=vega_path_check_logs bash run_vega_path_case.sh vega64_int8_outcastfp32_force_1x1_n32_c64_k64_20260318 -- \
  bash -lc 'set +e; MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 -i 1 -S GemmFwd1x1_0_1_int8 --out_cast_type fp32; ec=$?; echo __EXIT_CODE=$ec; exit 0'
```

---

## 4. 観測結果

Fact:

- `--out_cast_type int32` は 3 ケースとも
  `Invalid value for out_cast_type argument:int32`
  で `ParseCmdLineArgs()` 段階から失敗した。
- `--out_cast_type fp32` は受理された。
- `fp32` cast 時の runtime log では、
  output tensor descriptor は
  `dataType = 3` のままであり、
  `cast_type: Other` が付与されていた。
- 同じ `fp32` cast log では、
  find / cache key が
  `...NCHW-INT8-F_coFP32`
  になっていた。
- 同じ `fp32` cast log では、
  GEMM family に対して
  `GEMM not supported with casted tensors on this GPU architecture`
  が繰り返し記録された。
- 同条件では
  `GemmFwd1x1_0_1_int8: Not applicable`
  が自然選択側でも search 側でも記録された。
- forced
  `-S GemmFwd1x1_0_1_int8 --out_cast_type fp32`
  では
  `GetSolutionCountFallback` が
  `Requested convolution is not supported or Immediate mode Fallback unsuccessful.`
  を返し、
  `RunForwardGPU() FAILED, rc = 0x6`
  で止まった。

Interpretation:

- installed `MIOpenDriver` の legacy-style cast flag は
  **direct `y=int32` descriptor path の代替ではない**。
- 少なくとも今回の installed binary では、
  `--out_cast_type fp32` は
  output tensor の data type を `int32` に変えるのではなく、
  `int8 + cast metadata`
  として扱われている。
- その結果、問題表現自体が
  `...INT8-F_coFP32`
  へ変わり、
  gfx900 上の GEMM family は
  `casted tensors` 理由で落ちる。
- したがって、direct probe で通った
  `x=int8, w=int8, y=int32`
  path と、
  installed `MIOpenDriver convint8` の cast-flag path は
  同一視できない。

### 4.3 source-level descriptor split

Fact:

- current public standalone
  `MIOpen/driver/conv_driver.hpp`
  では、
  `data_type == miopenInt8 || data_type == miopenInt8x4`
  のとき
  `y_type = miopenInt32`
  を作り、
  `SetTensorNd(outputTensor, ..., y_type)`
  に渡している。
- same current public tree の
  `src/ocl/convolutionocl.cpp`
  では、
  `xDesc.GetType() == miopenInt8`
  の forward validation は
  `yDesc.GetType() == miopenInt32 || miopenFloat`
  を要求し、
  `miopenInt8x4` は `yDesc.GetType() == miopenInt32`
  を要求する。
- same current public tree の
  `src/include/miopen/conv/problem_description.hpp`
  では、
  `ProblemDescription::IsInt8()`
  は
  `GetOutDataType() == miopenInt32 || miopenFloat`
  だけを INT8 problem として扱う。
- same current public tree の
  `src/conv/problem_description.cpp`
  では、
  `BuildConfKey()` / `Serialize()` の dtype key は
  `GetInDataType()`, `GetWeightsDataType()`, `GetOutDataType()`
  だけで構成される。
- legacy
  `00_legacy-repos/MIOpen/driver/conv_driver.hpp`
  では、
  output tensor は `data_type` のまま作られ、
  その後 `miopenSetTensorCastType(outputTensor, out_cast_type)`
  が任意で付く。
- legacy
  `00_legacy-repos/MIOpen/src/include/miopen/conv/problem_description.hpp`
  では、
  `ProblemDescription::IsInt8()`
  は
  `GetOutDataType() == miopenInt32 || miopenInt8 || miopenFloat`
  を許し、
  同時に `IsTensorsCasted()` を別フラグで持つ。
- legacy
  `00_legacy-repos/MIOpen/src/solver/conv/gemm.cpp`
  では、
  `problem.IsTensorsCasted()`
  が立つと
  FP8-supported arch 以外では
  `GEMM not supported with casted tensors on this GPU architecture`
  で落ちる。

Interpretation:

- current public standalone source では、
  **direct `y=int32` route は tensor data type 自体を `miopenInt32` にする path**
  として表現されている。
- 一方 legacy cast-flag route は、
  **INT8 tensor に cast metadata を後付けする別 path**
  として表現されている。
- したがって、
  `...INT8INT8INT32-F`
  と
  `...INT8-F_coFP32`
  は
  同じ route の別表記ではなく、
  少なくとも source 上は別 problem として扱われている。
- 今回の direct probe が current source 側と整合し、
  installed `MIOpenDriver convint8` の cast-flag 振る舞いが
  legacy source 側と整合することから、
  現時点での practical blockage は
  少なくとも solver/backend 不在ではなく、
  **installed driver 側の descriptor assembly / path provenance**
  に強く寄っていると読める。

---

## 5. 判定

`confirmed`

少なくとも current installed `MIOpenDriver convint8` では、
legacy-style cast flag は存在するが、
`y=int32` descriptor を直接与えた path の代替にはならない。

---

## 6. 根拠リンク

- `../../vega_path_check_logs/vega64_int8_outcast32_nat_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_outcast32_search_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_outcast32_force_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_outcastfp32_nat_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_outcastfp32_search_1x1_n32_c64_k64_20260318.log`
- `../../vega_path_check_logs/vega64_int8_outcastfp32_force_1x1_n32_c64_k64_20260318.log`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/MIOpen/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/MIOpen/src/include/miopen/conv/problem_description.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/MIOpen/src/include/miopen/solver/problem_description_interpreter.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/MIOpen/src/solver/conv/gemm.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/include/miopen/conv/problem_description.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/conv/problem_description.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/ocl/convolutionocl.cpp`

---

## 本文書が主張しないこと

- installed `MIOpenDriver` の build provenance を断定するものではない
- current public standalone driver と installed driver の差分理由を断定するものではない
- `fp32` cast path があらゆる arch / dtype で GEMM を拒否すると一般化するものではない
- 特定組織や個人への批判を目的とするものではない
