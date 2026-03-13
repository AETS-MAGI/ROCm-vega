# TRACE MAP TEMPLATE

- case_id: vega64_fp32_nchw_group2_3x3
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.trace_extract.log

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| ConvMlirIgemm*: Not applicable |  | conv_mlir_igemm_fwd.cpp / bwd.cpp / wrw.cpp | 188 / 68 / 69 | gfx900 exclusion |
| ConvAsmImplicitGemm*: Not applicable |  | conv_asm_implicit_gemm_*_v4r1_dynamic.cpp | 293 / 343 / 142 / 306 | constraints not met, next solver tried |
| hipBlasLT failed, falling back to tensile |  | rocblas/library/src/tensile_host.cpp | 1232 | runtime fallback to Tensile |
| No Tensile solution found for XF32, fall back to FP32 |  | rocblas/library/src/tensile_host.cpp | 1161 | xF32 -> FP32 fallback |
| Skipped (non-dynamic) |  | include/miopen/find_solution.hpp | 324 / 449 | dynamic-only filter skip |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: ConvBinWinogradRxSf2x3
- kernel selected: miopenSp3AsmConv_v21_1_3_gfx9_fp32_f2x3_stride1
- dot4 instruction present: not checked in this case
- additional comments: group=2 case showed multiple Not applicable / Skipped lines before Winograd selection
