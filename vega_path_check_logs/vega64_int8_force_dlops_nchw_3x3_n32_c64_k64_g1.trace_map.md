# TRACE MAP

- case_id: vega64_int8_force_dlops_nchw_3x3_n32_c64_k64_g1
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_3x3_n32_c64_k64_g1.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_3x3_n32_c64_k64_g1.trace_extract.log

## 2. Key Evidence

- solver selected: ConvCkIgemmFwdV6r1DlopsNchw
- lines: 155:MIOpen(HIP): Info [GetSolutions] ;164:MIOpen(HIP): Info2 [GetSolutions] ConvDirectNaiveConvFwd;174:MIOpen(HIP): 	solution_id = 114;176:MIOpen(HIP): Info [GetForwardSolutionWorkspaceSize] solver_id = ConvCkIgemmFwdV6r1DlopsNchw;177:MIOpen Error: abyss-hbmx:/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/src/ocl/convolutionocl.cpp:1057: The supplied solution id: ConvCkIgemmFwdV6r1DlopsNchw is not applicable to the current problem;178:RunForwardGPU() FAILED, rc = 0x3;216:__EXIT_CODE=3;

## 3. Decision

- [need_more_cases] fallback_confirmed
- [need_more_cases] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
