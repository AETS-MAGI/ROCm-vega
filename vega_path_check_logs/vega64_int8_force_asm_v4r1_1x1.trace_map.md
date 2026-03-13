# TRACE MAP

- case_id: vega64_int8_force_asm_v4r1_1x1
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.trace_extract.log

## 2. Key Evidence

- solver selected: ConvAsmImplicitGemmV4R1DynamicFwd_1x1
- lines: 155:MIOpen(HIP): Info [GetSolutions] ;164:MIOpen(HIP): Info2 [GetSolutions] ConvDirectNaiveConvFwd;174:MIOpen(HIP): 	solution_id = 63;176:MIOpen(HIP): Info [GetForwardSolutionWorkspaceSize] solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1;183:MIOpen(HIP): 	solution_id = 63;185:MIOpen(HIP): Info [CompileSolution] solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1;226:MIOpen(HIP): 	solution_id = 63;229:MIOpen(HIP): Info [ConvolutionForwardImmediate] solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1, workspace = 0;233:Memory access fault by GPU node-1 (Agent handle: 0x55ddfc1287c0) on address 0x7f9e3486f000. Reason: Page not present or supervisor privilege.;

## 3. Decision

- [need_more_cases] fallback_confirmed
- [need_more_cases] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
