# TRACE MAP

- case_id: vega64_int8_force_dlops_nchw_1x1_n1_c32_k32_g1
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_1x1_n1_c32_k32_g1.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_nchw_1x1_n1_c32_k32_g1.trace_extract.log

## 2. Key Evidence

- solver selected: ConvCkIgemmFwdV6r1DlopsNchw
- lines: 155:MIOpen(HIP): Info2 [GetSolutionsFallback] Using WTI Fallback;156:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvDirectNaiveConvFwd Estimated WTI = 0.01;157:MIOpen(HIP): Info2 [GetSolutionsFallback] maxSolutionCount = 102, available = 1;158:MIOpen(HIP): Info2 [GetSolutionsFallback] id: 85, algo: 1, time: 1000, ws: 0, name: ConvDirectNaiveConvFwd;167:MIOpen(HIP): Info [GetSolutions] ;184:MIOpen(HIP): Info2 [GetSolutionsFallback] Using WTI Fallback;185:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvDirectNaiveConvFwd Estimated WTI = 0.01;186:MIOpen(HIP): Info2 [GetSolutionsFallback] maxSolutionCount = 1, available = 1;187:MIOpen(HIP): Info2 [GetSolutionsFallback] id: 85, algo: 1, time: 1000, ws: 0, name: ConvDirectNaiveConvFwd;197:MIOpen(HIP): 	solution_id = 114;199:MIOpen(HIP): Info [GetForwardSolutionWorkspaceSize] solver_id = ConvCkIgemmFwdV6r1DlopsNchw;200:MIOpen Error: abyss-hbmx:/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/src/ocl/convolutionocl.cpp:1057: The supplied solution id: ConvCkIgemmFwdV6r1DlopsNchw is not applicable to the current problem;

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases
## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
