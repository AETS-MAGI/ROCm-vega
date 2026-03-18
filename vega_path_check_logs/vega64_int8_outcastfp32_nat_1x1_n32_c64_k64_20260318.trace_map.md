# TRACE MAP TEMPLATE

- case_id: vega64_int8_outcastfp32_nat_1x1_n32_c64_k64_20260318
- status: fallback_confirmed / fallback_not_confirmed / need_more_cases

## 1. Observed Lines

- log: /home/limonene/ROCm-project/vega-hbmx-investigations/vega_investigations/vega_path_check_logs/vega64_int8_outcastfp32_nat_1x1_n32_c64_k64_20260318.log
- extract: /home/limonene/ROCm-project/vega-hbmx-investigations/vega_investigations/vega_path_check_logs/vega64_int8_outcastfp32_nat_1x1_n32_c64_k64_20260318.trace_extract.log

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
- [ ] need_more_cases

## 4. Notes

- solver selected:
- kernel selected:
- dot4 instruction present:
- additional comments:
