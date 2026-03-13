# solver_observation_log

更新日: 2026-03-13
対象: Vega64実機 (ROCm表示: gfx900:xnack-)

## 1. 要約

- FP32 では Winograd / ASM 1x1 / ImplicitGEMM など複数solverが観測された。
- INT8 では探索した全ケースで `ConvDirectNaiveConvFwd` が選択された。
- INT8 の検索ログでは `ConvAsmImplicitGemmV4R1Dynamic*` が `Not applicable`、`ConvMlirIgemm*` が `Skipped (non-dynamic)` を繰り返し観測。

## 2. FP32 観測

- `vega64_fp32_nchw_3x3_fwd_n32`
  - solver: `ConvBinWinograd3x3U`
  - kernel: `miopenSp3AsmConv3x3F`
- `vega64_fp32_nchw_1x1_fwd_n32`
  - solver: `ConvAsm1x1U`
  - kernel: `miopenGcnAsmConv1x1U`
- `vega64_fp32_nchw_3x3_s2_k128`
  - solver: `ConvHipImplicitGemmV4R1Fwd`
  - kernel: `gridwise_convolution_implicit_gemm_v4r1_nchw_kcyx_nkhw_lds_double_buffer`
- `vega64_fp32_nchw_group2_3x3`
  - solver: `ConvBinWinogradRxSf2x3`
  - kernel: `miopenSp3AsmConv_v21_1_3_gfx9_fp32_f2x3_stride1`

## 3. INT8 観測

- `vega64_int8_nchw_1x1_fwd_n32`
- `vega64_i8_case1`
- `vega64_int8_3x3_s1_n32_c64_k64`
- `vega64_int8_3x3_s2_n32_c64_k128`
- `vega64_int8_1x1_group2_n32_c64_k64`
- `vega64_int8_1x1_n16_c128_k128`
- `vega64_int8_nchw_3x3_search1`
- `vega64_int8_nhwc_1x1_s1`
- `vega64_int8_nhwc_3x3_search1`

全ケース共通:

- solver: `ConvDirectNaiveConvFwd`
- kernel: `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t` (ログで観測)

## 4. 命令観測

- ukdb から `naive_conv.cpp.o` (INT8 条件行) を抽出して逆アセンブル実施。
- `v_dot4_i32_i8` / `v_dot4c_i32_i8` / `sdot4` / `sudot4` は未検出。
- `v_mul*` / `v_add*` 系は検出。

## 5. 未解決

- `ConvAsmImplicitGemmV4R1Dynamic*` が選択される INT8 条件は未発見。
- `ConvMlirIgemm*` の実行時除外をより直接に示すケース整理が必要。
- 比較GPUとの差分取得が未実施。
