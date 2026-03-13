# TRACE MAP

- case_id: vega64_int8_force_mlir_fwd
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.trace_extract.log

## 2. Key Evidence

- solver selected: ConvMlirIgemmFwd
- lines: 155:MIOpen(HIP): Info [GetSolutions] ;164:MIOpen(HIP): Info2 [GetSolutions] ConvDirectNaiveConvFwd;174:MIOpen(HIP): 	solution_id = 98;176:MIOpen(HIP): Info [GetForwardSolutionWorkspaceSize] solver_id = ConvMlirIgemmFwd;183:MIOpen(HIP): 	solution_id = 98;185:MIOpen(HIP): Info [CompileSolution] solver_id = ConvMlirIgemmFwd;207:MIOpen Error: abyss-hbmx:/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/src/mlir_build.cpp:59: miirLowerTuningParams MIIR_INVALID_PARAM;208:RunForwardGPU() FAILED, rc = 0x7;246:__EXIT_CODE=7;

## 3. Decision

- [need_more_cases] fallback_confirmed
- [need_more_cases] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
