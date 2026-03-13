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

## 判定

- status: `need_more_cases`
- 理由: solver 選択の実測は進んだが、dot4 命令有無の逆アセンブル確認が未実施。

## 次アクション

1. INT8 ケースの hsaco を抽出し、dot4 / 非dot4 命令列を逆アセンブルで確認する。
2. `ConvAsmImplicitGemmV4R1Dynamic*` が `Not applicable` になる条件を shape と dtype で切り分ける。
3. 可能なら比較 GPU で同一ケースを実行し、solver 差分を取る。
