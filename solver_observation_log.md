# solver_observation_log

更新日: 2026-03-13
対象: Vega64実機 (ROCm表示: gfx900:xnack-)

## 1. 要約

- FP32 では Winograd / ASM 1x1 / ImplicitGEMM など複数solverが観測された。
- INT8 では探索した全ケースで `ConvDirectNaiveConvFwd` が選択された。
- INT8 の検索ログでは `ConvAsmImplicitGemmV4R1Dynamic*` が `Not applicable`、`ConvMlirIgemm*` が `Skipped (non-dynamic)` を繰り返し観測。
- `-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の強制実行では compile/immediate まで進むが、実行時に GPU memory access fault を観測。
- `-S ConvMlirIgemmFwd` の強制実行では compile/find まで進むが、`MIIR_INVALID_PARAM` で `RunForwardGPU() FAILED (rc=0x7)` を観測。
- `-S ConvCkIgemmFwdV6r1DlopsNchw` の強制実行では `not applicable to the current problem` で `RunForwardGPU() FAILED (rc=0x3)` を観測。

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
- `ConvMlirIgemm*` の自然選択成立条件は未発見（強制実行失敗は確認済み）。
- 比較GPUとの差分取得が未実施。

## 6. 強制solverケース (追加)

- case: `vega64_int8_force_asm_v4r1_1x1`
- command: `convint8 ... -S ConvAsmImplicitGemmV4R1DynamicFwd_1x1`
- log観測:
  - `GetSolutions`: `ConvDirectNaiveConvFwd` (id 85)
  - `solution_id = 63` 指定で `CompileSolution` 実行
  - `ConvolutionForwardImmediate` (`solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1`) 実行
  - `Memory access fault by GPU node-1`
- 解釈: 自然選択経路と強制実行経路を切り分けて記録できたが、実運用での成立条件は未確定。

## 7. 強制MLIRケース (追加)

- case: `vega64_int8_force_mlir_fwd`
- command: `convint8 ... -S ConvMlirIgemmFwd`
- log観測:
  - `GetSolutions`: `ConvDirectNaiveConvFwd` (id 85)
  - `solution_id = 98` 指定で `CompileSolution` 実行
  - `FindSolutionImpl` 中に `Perf Db: record not found for: ConvMlirIgemmFwd`
  - `miirLowerTuningParams MIIR_INVALID_PARAM`
  - `RunForwardGPU() FAILED, rc = 0x7` (`__EXIT_CODE=7`)
- 解釈: `ConvMlirIgemm*` は「skipされる」だけでなく、強制実行条件での実行失敗も直接観測できた。

## 8. 強制DLOPSケース (追加)

- case: `vega64_int8_force_dlops_ck`
- command: `convint8 ... -S ConvCkIgemmFwdV6r1DlopsNchw`
- log観測:
  - `GetSolutions`: `ConvDirectNaiveConvFwd` (id 85)
  - `solution_id = 114` 指定で `GetForwardSolutionWorkspaceSize` まで進行
  - `The supplied solution id: ConvCkIgemmFwdV6r1DlopsNchw is not applicable to the current problem`
  - `RunForwardGPU() FAILED, rc = 0x3` (`__EXIT_CODE=3`)
- 解釈: DLOPS系solverの実行不成立を強制実行で直接確認。成立条件の追加切り分けが必要。

## 9. 強制DLOPSグリッド (追加)

- 対象solver: `ConvCkIgemmFwdV6r1DlopsNchw`
- 実施: 7ケース（NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2）
- 結果: 全ケースで
  - `The supplied solution id ... is not applicable to the current problem`
  - `RunForwardGPU() FAILED, rc = 0x3`
- 解釈: 少なくとも今回の形状・layout・group範囲では DLOPS成立条件に到達していない。

## 10. 強制DLOPSグリッド search=1 (追加)

- 対象solver: `ConvCkIgemmFwdV6r1DlopsNchw`
- 実施: 8ケース（`-s 1`, C/K=128/256, NCHW/NHWC, 1x1/3x3, stride1/2, g=1/2）
- 結果: 全ケースで
  - `The supplied solution id ... is not applicable to the current problem`
  - `RunForwardGPU() FAILED, rc = 0x3`
- 解釈: search有効化とC/K極値を加えても適用不可は不変。次は別DLOPS solver familyの切り分けが必要。

## 11. 強制HipImplicitGemm Xdlops (追加)

- case: `vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3`
- command: `convint8 ... -S ConvHipImplicitGemmFwdXdlops`
- log観測:
  - `GetForwardSolutionWorkspaceSize` (`solver_id = ConvHipImplicitGemmFwdXdlops`)
  - `CompileSolution` -> `GetInvoker` -> `FindSolutionImpl`
  - `std::vector<std::basic_string<char>>::operator[] ... Assertion '__n < this->size()' failed`
  - 実行は abort (`EXIT=134`)

- case: `vega64_int8_force_hipigemm_v4r5xdlops_nchw_3x3`
- command: `convint8 ... -S ConvHipImplicitGemmForwardV4R5Xdlops`
- log観測:
  - `GetForwardSolutionWorkspaceSize` (`solver_id = ConvHipImplicitGemmForwardV4R5Xdlops`)
  - `CompileSolution` -> `GetInvoker` -> `FindSolutionImpl`
  - xdlops kernel compile失敗 (`intrin_mfma_*`/`gcnasm_mfma_*`/`FLOAT` 関連)
  - `Code object build failed` -> `RunForwardGPU() FAILED, rc = 0x7`

- case: `vega64_int8_force_hipigemm_groupfwdxdlops_nchw_g2_3x3`
- command: `convint8 ... -g 2 ... -S ConvHipImplicitGemmGroupFwdXdlops`
- log観測:
  - `solver_id = ConvHipImplicitGemmGroupFwdXdlops`
  - `The supplied solution id ... is not applicable to the current problem`
  - `RunForwardGPU() FAILED, rc = 0x3`

- 解釈: HipImplicitGemm系Xdlopsでは、`not applicable` だけでなく abort と compile failure も観測され、solver familyで失敗様式が分岐する。

## 12. dtype 軸プローブ (追加)

- case: `vega64_fp16_nchw_3x3_probe`
  - solver: `ConvOclDirectFwd`
  - algorithm: `miopenConvolutionFwdAlgoDirect` (Solution `11/ConvOclDirectFwd`)
  - elapsed: `4.319100 ms`

- case: `vega64_bfp16_nchw_3x3_probe`
  - solver: `GemmFwdRest`
  - algorithm: `miopenConvolutionFwdAlgoGEMM` (Solution `91/GemmFwdRest`)
  - elapsed: `5.411226 ms`

- 解釈: 同一problemでも dtype により solver family が切り替わることを実測で確認。

## 13. FP16/BFP16 強制HipImplicitGemm Xdlops (追加)

- case: `vega64_fp16_force_hipigemm_fwdxdlops_nchw_3x3`
- command: `convfp16 ... -S ConvHipImplicitGemmFwdXdlops`
- log観測:
  - `solver_id = ConvHipImplicitGemmFwdXdlops`
  - `CompileSolution` -> `GetInvoker` -> `FindSolutionImpl`
  - `std::vector<std::basic_string<char>>::operator[] ... Assertion '__n < this->size()' failed`
  - `__EXIT_CODE=134`

- case: `vega64_fp16_force_hipigemm_v4r5xdlops_nchw_3x3`
- command: `convfp16 ... -S ConvHipImplicitGemmForwardV4R5Xdlops`
- log観測:
  - `solver_id = ConvHipImplicitGemmForwardV4R5Xdlops`
  - `CompileSolution` -> `GetInvoker` -> `FindSolutionImpl`
  - `Code object build failed` -> `RunForwardGPU() FAILED, rc = 0x7`
  - `__EXIT_CODE=7`

- case: `vega64_bfp16_force_hipigemm_fwdxdlops_nchw_3x3`
- command: `convbfp16 ... -S ConvHipImplicitGemmFwdXdlops`
- 結果: FP16同様に assertion abort (`__EXIT_CODE=134`)

- case: `vega64_bfp16_force_hipigemm_v4r5xdlops_nchw_3x3`
- command: `convbfp16 ... -S ConvHipImplicitGemmForwardV4R5Xdlops`
- 結果: FP16同様に `Code object build failed` -> `rc=0x7` (`__EXIT_CODE=7`)

- 解釈: FwdXdlops/V4R5Xdlops の失敗様式は FP16/BFP16 でもINT8と同型で、dtypeよりsolver実装系側の制約が支配的な可能性が高い。

## 14. ローカルDebug版MIOpen再ビルド（WD-Black再試行）

- 目的:
  - `ConvMlirIgemmFwd` 強制ケースをローカルDebug版MIOpenで再現し、`MIIR_INVALID_PARAM` 前後の分岐観測に進む。
- 実行メモ:
  - WD-Black を `/home/limonene/ROCm-project/WD-Black` にマウントし、build/prefix を同デバイスへ移動。
  - 初回WD-Black試行 (`miopen_debug_build_20260313_213006_wdblack.log`) は `git describe` 起因で configure 停滞。
  - `EXTRA_CMAKE_ARGS` に `-DGIT=/bin/false -DGit_EXECUTABLE=/bin/false` を追加して停滞回避。
  - 次試行で `frugally-deep` 必須エラーを観測し、`-DMIOPEN_ENABLE_AI_IMMED_MODE_FALLBACK=Off -DMIOPEN_ENABLE_AI_KERNEL_TUNING=Off` を追加。
  - 現在の有効試行: `tmp/miopen_debug_build_20260313_215209_wdblack.log`。
- 現状:
  - configure は前進しており、`HALF_INCLUDE_DIR` は `/usr/include` で解決済み。
  - 完了待ちのため、ローカルprefixを使った `ConvMlirIgemmFwd` 再現はこのビルド完了後に実施。
