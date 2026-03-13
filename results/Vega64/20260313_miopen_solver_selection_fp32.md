# 20260313 MIOpen solver selection (FP32)

## 目的

Vega64 実機（CLI 表示は RX Vega / gfx900）で、FP32 Conv の solver 選択経路を確認する。

## 環境

- Host: abyss-hbmx
- ROCm: 7.2.26043
- MIOpen Driver: 3.5.1
- GPU (rocminfo/rocm-smi): AMD Radeon RX Vega, gfx900
- 備考: 実機は Vega64 として運用中。ROCm の表示は RX Vega (gfx900)。

## 実行コマンド

1. 3x3 ケース

```bash
bash run_vega_path_case.sh vega64_fp32_nchw_3x3_fwd_n32 -- \
  MIOpenDriver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1
```

2. 1x1 ケース

```bash
bash run_vega_path_case.sh vega64_fp32_nchw_1x1_fwd_n32 -- \
  MIOpenDriver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1
```

## 観測結果

1. 3x3 ケース (`vega64_fp32_nchw_3x3_fwd_n32`)
- Device: `gfx900:xnack-`
- solver: `ConvBinWinograd3x3U`
- kernel: `miopenSp3AsmConv3x3F`
- forward verify: OK

2. 1x1 ケース (`vega64_fp32_nchw_1x1_fwd_n32`)
- Device: `gfx900:xnack-`
- solver: `ConvAsm1x1U`
- kernel: `miopenGcnAsmConv1x1U`
- forward verify: OK

3. 3x3 stride2 ケース (`vega64_fp32_nchw_3x3_s2_k128`)
- Device: `gfx900:xnack-`
- solver: `ConvHipImplicitGemmV4R1Fwd`
- kernel: `gridwise_convolution_implicit_gemm_v4r1_nchw_kcyx_nkhw_lds_double_buffer`
- forward verify: OK

4. 3x3 group=2 ケース (`vega64_fp32_nchw_group2_3x3`)
- Device: `gfx900:xnack-`
- solver: `ConvBinWinogradRxSf2x3`
- kernel: `miopenSp3AsmConv_v21_1_3_gfx9_fp32_f2x3_stride1`
- forward verify: OK

5. INT8 1x1 ケース (`vega64_int8_nchw_1x1_fwd_n32`)
- Device: `gfx900:xnack-`
- solver: `ConvDirectNaiveConvFwd`
- kernel: `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t`
- 観測: `ConvAsmImplicitGemmV4R1Dynamic*` が `Not applicable`、`ConvMlirIgemm*` が `Skipped (non-dynamic)`

6. INT8 小形状ケース (`vega64_i8_case1`)
- Device: `gfx900:xnack-`
- solver: `ConvDirectNaiveConvFwd`
- kernel: `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t`

7. INT8 追加スイープ（非 naive 探索）
- `vega64_int8_3x3_s1_n32_c64_k64`: `ConvDirectNaiveConvFwd`
- `vega64_int8_3x3_s2_n32_c64_k128`: `ConvDirectNaiveConvFwd`
- `vega64_int8_1x1_group2_n32_c64_k64`: `ConvDirectNaiveConvFwd`
- `vega64_int8_1x1_n16_c128_k128`: `ConvDirectNaiveConvFwd`
- `vega64_int8_nchw_3x3_search1`: `ConvDirectNaiveConvFwd`
- `vega64_int8_nhwc_1x1_s1`: `ConvDirectNaiveConvFwd`
- `vega64_int8_nhwc_3x3_search1`: `ConvDirectNaiveConvFwd`
- 追加した範囲では naive 以外の INT8 solver は観測できなかった

8. INT8 強制solverケース (`vega64_int8_force_asm_v4r1_1x1`)
- command: `convint8 ... -S ConvAsmImplicitGemmV4R1DynamicFwd_1x1`
- library report: `ConvDirectNaiveConvFwd` (id 85)
- forced path: `solution_id = 63` -> `CompileSolution` -> `ConvolutionForwardImmediate` (`solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1`)
- runtime result: `Memory access fault by GPU node-1`
- 解釈: 自然選択ではnaive、強制指定では対象solverの実行に進むが、当該条件で実行時fault。

9. INT8 強制MLIRケース (`vega64_int8_force_mlir_fwd`)
- command: `convint8 ... -S ConvMlirIgemmFwd`
- library report: `ConvDirectNaiveConvFwd` (id 85)
- forced path: `solution_id = 98` -> `CompileSolution` (`solver_id = ConvMlirIgemmFwd`) -> `FindSolutionImpl`
- runtime result:
  - `Perf Db: record not found for: ConvMlirIgemmFwd`
  - `miirLowerTuningParams MIIR_INVALID_PARAM`
  - `RunForwardGPU() FAILED, rc = 0x7` (`__EXIT_CODE=7`)
- 解釈: `ConvMlirIgemm*` について「Skipped (non-dynamic)」だけでなく、強制実行時に実行失敗する直接証跡を取得。

10. INT8 強制DLOPSケース (`vega64_int8_force_dlops_ck`)
- command: `convint8 ... -S ConvCkIgemmFwdV6r1DlopsNchw`
- library report: `ConvDirectNaiveConvFwd` (id 85)
- forced path: `solution_id = 114` -> `GetForwardSolutionWorkspaceSize` (`solver_id = ConvCkIgemmFwdV6r1DlopsNchw`)
- runtime result:
  - `The supplied solution id: ConvCkIgemmFwdV6r1DlopsNchw is not applicable to the current problem`
  - `RunForwardGPU() FAILED, rc = 0x3` (`__EXIT_CODE=3`)
- 解釈: DLOPS系solverの「適用不可」を強制実行で直接確認。少なくともこのINT8 3x3条件では成立しない。

11. INT8 強制DLOPSグリッド（追加）
- 対象solver: `ConvCkIgemmFwdV6r1DlopsNchw`
- ケース: 7件（NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2）
- 結果: 全件 `not applicable to the current problem` + `RunForwardGPU() FAILED, rc = 0x3`
- 解釈: 今回の shape/layout/group 範囲では DLOPS 成立条件に到達できなかった。

12. INT8 強制DLOPSグリッド（search=1 + C/K極値）
- 対象solver: `ConvCkIgemmFwdV6r1DlopsNchw`
- ケース: 8件（`-s 1`、NCHW/NHWC、1x1/3x3、C/K=128/256、stride1/2、g=1/2）
- 結果: 全件 `not applicable to the current problem` + `RunForwardGPU() FAILED, rc = 0x3`
- 解釈: `-s 1` と C/K極値を入れても DLOPS 成立条件に到達できず、現状は適用不可が一貫。

13. INT8 強制HipImplicitGemm Xdlops（solver family 切り分け）
- `vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3`
  - command: `convint8 ... -S ConvHipImplicitGemmFwdXdlops`
  - 観測: `CompileSolution` / `GetInvoker` / `FindSolutionImpl` までは進行
  - 結果: `std::vector<...>::operator[]` assertion (`__n < this->size()`) で abort (`EXIT=134`)
- `vega64_int8_force_hipigemm_v4r5xdlops_nchw_3x3`
  - command: `convint8 ... -S ConvHipImplicitGemmForwardV4R5Xdlops`
  - 観測: `CompileSolution` / `GetInvoker` / `FindSolutionImpl` までは進行
  - 結果: xdlops kernel compile failure (`no template named intrin_mfma_*`, `gcnasm_mfma_* undeclared`, `FLOAT unknown`) -> `Code object build failed` -> `RunForwardGPU() FAILED, rc = 0x7`
- `vega64_int8_force_hipigemm_groupfwdxdlops_nchw_g2_3x3`
  - command: `convint8 ... -g 2 ... -S ConvHipImplicitGemmGroupFwdXdlops`
  - 観測/結果: `not applicable to the current problem` -> `RunForwardGPU() FAILED, rc = 0x3`
- 解釈: CK DLOPS とは異なる失敗モード（abort / compile失敗 / not applicable）が確認でき、solver familyごとに失敗境界が異なる。

14. dtype 軸プローブ（同形状 3x3）
- `vega64_fp16_nchw_3x3_probe`
  - command: `convfp16 -n 16 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -s 1 -F 1 -t 1`
  - solver: `ConvOclDirectFwd` (`miopenConvolutionFwdAlgoDirect`)
  - elapsed: `4.319100 ms`
- `vega64_bfp16_nchw_3x3_probe`
  - command: `convbfp16 -n 16 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -s 1 -F 1 -t 1`
  - solver: `GemmFwdRest` (`miopenConvolutionFwdAlgoGEMM`, Solution `91/GemmFwdRest`)
  - elapsed: `5.411226 ms`
- 解釈: 同一problemでも FP16/BFP16 で solver family が分岐した（Direct vs GEMM）。

## 根拠リンク（ログ）

- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_fwd_n32.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_fwd_n32.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_fwd_n32.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_1x1_fwd_n32.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_1x1_fwd_n32.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_1x1_fwd_n32.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_s2_k128.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_s2_k128.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_s2_k128.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_1x1_fwd_n32.log
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_1x1_fwd_n32.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_1x1_fwd_n32.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_i8_case1.log
- /home/limonene/vega_path_check_logs/vega64_i8_case1.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_i8_case1.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s1_n32_c64_k64.log
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s1_n32_c64_k64.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s1_n32_c64_k64.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s2_n32_c64_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s2_n32_c64_k128.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_3x3_s2_n32_c64_k128.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_group2_n32_c64_k64.log
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_group2_n32_c64_k64.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_group2_n32_c64_k64.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_n16_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_n16_c128_k128.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_1x1_n16_c128_k128.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_3x3_search1.log
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_3x3_search1.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_nchw_3x3_search1.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_1x1_s1.log
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_1x1_s1.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_1x1_s1.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_3x3_search1.log
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_3x3_search1.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_nhwc_3x3_search1.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_1x1_n1_c32_k32_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_1x1_n1_c64_k64_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_3x3_n1_c64_k64_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_3x3_n32_c64_k64_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_3x3_n32_c64_k64_g2.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nhwc_1x1_n16_c64_k64_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nhwc_3x3_n16_c64_k64_g1.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_1x1_n1_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_1x1_n1_c256_k256.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_3x3_n1_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_3x3_n1_c128_k128_s2.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_3x3_n32_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nchw_3x3_n32_c128_k128_g2.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nhwc_1x1_n16_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_s1_nhwc_3x3_n16_c128_k128.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_v4r5xdlops_nchw_3x3.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_v4r5xdlops_nchw_3x3.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_v4r5xdlops_nchw_3x3.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_groupfwdxdlops_nchw_g2_3x3.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_groupfwdxdlops_nchw_g2_3x3.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_int8_force_hipigemm_groupfwdxdlops_nchw_g2_3x3.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_fp16_nchw_3x3_probe.log
- /home/limonene/vega_path_check_logs/vega64_fp16_nchw_3x3_probe.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_fp16_nchw_3x3_probe.trace_map.md
- /home/limonene/vega_path_check_logs/vega64_bfp16_nchw_3x3_probe.log
- /home/limonene/vega_path_check_logs/vega64_bfp16_nchw_3x3_probe.solver_extract.log
- /home/limonene/vega_path_check_logs/vega64_bfp16_nchw_3x3_probe.trace_map.md

## 判定

- status: `need_more_cases`
- 理由: dot4 有無の一次確認は実施済みだが、naive 以外の INT8 kernel や比較GPUとの突合が未実施。

## 逆アセンブル追記（INT8）

- 対象DB: `~/.cache/miopen/3.5.1.5b515cf1bca-dirty/gfx900_64.ukdb`
- `kern_db` から `naive_conv.cpp.o` (INT8条件行) を抽出
- 抽出blobは bzip2 圧縮で、展開後は `ELF 64-bit ... elf64-amdgpu`
- `llvm-objdump -d --triple=amdgcn` で逆アセンブル

実行メモ:

```bash
sqlite3 "$DB" "SELECT writefile('/tmp/miopen_extract/naive_conv_int8.cpp.o.bz2', kernel_blob) FROM kern_db WHERE kernel_name='naive_conv.cpp.o' AND instr(kernel_args,'MIOPEN_USE_INT8=1')>0 LIMIT 1;"
bzip2 -dc /tmp/miopen_extract/naive_conv_int8.cpp.o.bz2 > /tmp/miopen_extract/naive_conv_int8.cpp.o
/opt/rocm/llvm/bin/llvm-objdump -d --triple=amdgcn /tmp/miopen_extract/naive_conv_int8.cpp.o > /tmp/miopen_extract/naive_conv_int8.cpp.o.s
rg -n "v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4" /tmp/miopen_extract/naive_conv_int8.cpp.o.s
```

観測:

- INT8対象シンボル `naive_conv_ab_nonpacked_fwd_nchw_int8_t_int32_t_int8_t` を確認
- `v_dot4_i32_i8` / `v_dot4c_i32_i8` / `sdot4` / `sudot4` は未検出
- `v_mul*` / `v_add*` 系命令は検出

暫定解釈:

- 今回取得できた INT8 naive kernel では dot4 系命令は使われていない。
- dot4 非依存の代替積和経路候補として整合的。

## 次アクション

1. `ConvAsmImplicitGemmV4R1Dynamic*` が `Not applicable` になる条件を shape と dtype で切り分ける。
2. INT8 で naive 以外の kernel が選ばれるケースを探索し、同様に逆アセンブル比較する。
3. 可能なら比較 GPU で同一ケースを実行し、solver 差分を取る。

補足:

- 追加スイープでも INT8 はすべて `ConvDirectNaiveConvFwd` だったため、次は入力レイアウトや問題サイズの軸を広げる必要がある。
- `-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の強制実行では immediate まで進行したが、実行時に GPU memory access fault で停止した。
- `-S ConvMlirIgemmFwd` の強制実行では `CompileSolution` まで進むが、`MIIR_INVALID_PARAM` により `RunForwardGPU()` が失敗した。
- `-S ConvCkIgemmFwdV6r1DlopsNchw` の強制実行では `not applicable to the current problem` で `RunForwardGPU() FAILED (rc=0x3)` となった。
- `-S ConvHipImplicitGemmFwdXdlops` の強制実行では `FindSolutionImpl` 後に `std::vector::operator[]` assertion で abort (`EXIT=134`)。
- `-S ConvHipImplicitGemmForwardV4R5Xdlops` の強制実行では xdlops kernel compile failure で `Code object build failed` -> `RunForwardGPU() FAILED (rc=0x7)`。
- `-S ConvHipImplicitGemmGroupFwdXdlops` (`g=2`) の強制実行では `not applicable` で `RunForwardGPU() FAILED (rc=0x3)`。
- 同形状 3x3 で dtype を FP16/BFP16 に変えると、FP16 は `ConvOclDirectFwd`、BFP16 は `GemmFwdRest` が選択された。
