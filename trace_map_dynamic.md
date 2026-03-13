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
- 強制solverケース (`-S ConvCkIgemmFwdV6r1DlopsNchw`) では:
  - `GetForwardSolutionWorkspaceSize` まで進行
  - `not applicable to the current problem` -> `RunForwardGPU() FAILED, rc = 0x3`
  - 追加グリッド7ケース（NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2）でも全件 `not applicable`
  - 追加グリッド8ケース（`-s 1`, C/K=128/256, stride1/2, g=1/2）でも全件 `not applicable`
- 強制solverケース (`-S ConvHipImplicitGemmFwdXdlops`) では:
  - `CompileSolution` / `GetInvoker` / `FindSolutionImpl` まで進行
  - `std::vector<...>::operator[]` assertion (`__n < this->size()`) で abort (`EXIT=134`)
- 強制solverケース (`-S ConvHipImplicitGemmForwardV4R5Xdlops`) では:
  - `CompileSolution` / `GetInvoker` / `FindSolutionImpl` まで進行
  - xdlops kernel compile失敗 (`intrin_mfma_*` / `gcnasm_mfma_*` / `FLOAT`)
  - `Code object build failed` -> `RunForwardGPU() FAILED, rc = 0x7`
- 強制solverケース (`-S ConvHipImplicitGemmGroupFwdXdlops`, g=2) では:
  - `not applicable to the current problem` -> `RunForwardGPU() FAILED, rc = 0x3`

### 2.3 dtype 軸（同形状3x3）

- FP16 (`convfp16`):
  - `ConvOclDirectFwd` -> `miopenConvolutionFwdAlgoDirect`
  - elapsed: `4.319100 ms`
- BFP16 (`convbfp16`):
  - `GemmFwdRest` -> `miopenConvolutionFwdAlgoGEMM`
  - elapsed: `5.411226 ms`
- 含意:
  - 同一problemでも dtype で solver family が分岐する。
  - ただし `-S ConvHipImplicitGemmFwdXdlops` 強制時は FP16/BFP16 とも assertion abort (`EXIT=134`)。
  - `-S ConvHipImplicitGemmForwardV4R5Xdlops` 強制時は FP16/BFP16 とも `Code object build failed` -> `rc=0x7`。

## 3. 補助観測

- INT8ケースで `ConvAsmImplicitGemmV4R1Dynamic*` は `Not applicable` を繰り返し観測。
- INT8ケースで `ConvMlirIgemm*` は `Skipped (non-dynamic)` を繰り返し観測。
- 抽出kernel逆アセンブルで dot4 命令は未検出。
- 強制指定時は `solution_id=63` で `ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の実行に進むが、当該条件では実行完了せずfaultで停止。
- 強制指定時は `solution_id=98` で `ConvMlirIgemmFwd` の実行に進むが、当該条件では `MIIR_INVALID_PARAM` で失敗。
- 強制指定時は `solution_id=114` で `ConvCkIgemmFwdV6r1DlopsNchw` を試行するが、当該条件では `not applicable` で失敗。
- 強制指定時は `ConvHipImplicitGemmFwdXdlops` を試行すると、適用判定の先で assertion abort に到達する。
- 強制指定時は `ConvHipImplicitGemmForwardV4R5Xdlops` を試行すると、kernel compile失敗で `rc=0x7` に到達する。
- 強制指定時は `ConvHipImplicitGemmGroupFwdXdlops` を試行すると、当該条件では `not applicable` で失敗する。
- 強制指定時は `ConvHipImplicitGemmFwdXdlops` を FP16/BFP16 で試行しても assertion abort に到達する。
- 強制指定時は `ConvHipImplicitGemmForwardV4R5Xdlops` を FP16/BFP16 で試行しても compile failure (`rc=0x7`) に到達する。

## 4. 判定

- status: `need_more_cases`
- 理由: INT8 の非-naive solver が未観測で、比較GPUとの差分も未取得。

## 5. 次の探索軸

1. INT8 の shape 範囲をさらに拡大（N/K/C の極端値、dilation/pad/stride組み合わせ）。
2. 即時モード (`-S`) による候補solver単体実行可否を確認。
3. 比較GPUで同一ケースを実行して solver 差分を取る。
