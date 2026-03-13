# trace_map_dynamic

更新日: 2026-03-13

## 1. 目的

Vega64(gfx900) 実機で、実行時にどの solver / kernel に落ちるかを動的ログから確定する。

## 2. 現時点の経路マップ

### 2.1 FP32

- 3x3 NCHW s1:
  - `ConvBinWinograd3x3U` -> `miopenSp3AsmConv3x3F`
- 1x1 NCHW s1:
  - `ConvAsm1x1U` -> `miopenGcnAsmConv1x1U`
- 3x3 NCHW s2 (k=128):
  - `ConvHipImplicitGemmV4R1Fwd` -> `gridwise_convolution_implicit_gemm_v4r1_nchw_kcyx_nkhw_lds_double_buffer`
- 3x3 NCHW group=2:
  - `ConvBinWinogradRxSf2x3` -> `miopenSp3AsmConv_v21_1_3_gfx9_fp32_f2x3_stride1`

### 2.2 INT8

- NCHW / NHWC / group / stride / search=1 を含む複数条件で:
  - `ConvDirectNaiveConvFwd` -> `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t`
- 強制solverケース (`-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1`) では:
  - `CompileSolution` / `ConvolutionForwardImmediate` まで進行
  - その後 `Memory access fault by GPU node-1`
- 強制solverケース (`-S ConvMlirIgemmFwd`) では:
  - `CompileSolution` / `FindSolutionImpl` まで進行
  - `miirLowerTuningParams MIIR_INVALID_PARAM` -> `RunForwardGPU() FAILED, rc = 0x7`

## 3. 補助観測

- INT8ケースで `ConvAsmImplicitGemmV4R1Dynamic*` は `Not applicable` を繰り返し観測。
- INT8ケースで `ConvMlirIgemm*` は `Skipped (non-dynamic)` を繰り返し観測。
- 抽出kernel逆アセンブルで dot4 命令は未検出。
- 強制指定時は `solution_id=63` で `ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の実行に進むが、当該条件では実行完了せずfaultで停止。
- 強制指定時は `solution_id=98` で `ConvMlirIgemmFwd` の実行に進むが、当該条件では `MIIR_INVALID_PARAM` で失敗。

## 4. 判定

- status: `need_more_cases`
- 理由: INT8 の非-naive solver が未観測で、比較GPUとの差分も未取得。

## 5. 次の探索軸

1. INT8 の shape 範囲をさらに拡大（N/K/C の極端値、dilation/pad/stride組み合わせ）。
2. 即時モード (`-S`) による候補solver単体実行可否を確認。
3. 比較GPUで同一ケースを実行して solver 差分を取る。
