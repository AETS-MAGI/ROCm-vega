# TRACE MAP

- case_id: vega64_fp16_force_hipigemm_v4r5xdlops_nchw_3x3
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp16_force_hipigemm_v4r5xdlops_nchw_3x3.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp16_force_hipigemm_v4r5xdlops_nchw_3x3.trace_extract.log

## 2. Key Evidence

- solver_id: ConvHipImplicitGemmForwardV4R5Xdlops
- outcome: code object build failed
- lines: 287:MIOpen Error: abyss-hbmx:/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/src/hipoc/hipoc_program.cpp:299: Code object build failed. Source: static_kernel_gridwise_convolution_forward_implicit_gemm_v4r5_xdlops_nchw_kcyx_nkhw.cpp;288:RunForwardGPU() FAILED, rc = 0x7;326:__EXIT_CODE=7;

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: ConvHipImplicitGemmForwardV4R5Xdlops
- kernel selected: n/a (forced solver path)
- dot4 instruction present: n/a
- additional comments: Forced HipImplicitGemm Xdlops probe for dtype-axis comparison.
