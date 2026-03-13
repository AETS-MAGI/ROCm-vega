# TRACE MAP TEMPLATE

- case_id: vega64_int8_force_asm_v4r1_1x1
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.trace_extract.log

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| GetSolutions: ConvDirectNaiveConvFwd | 164-166 | n/a (runtime selection result) | n/a | library report上はnaiveが候補 |
| solution_id = 63 / solver_id = ConvAsmImplicitGemmV4R1DynamicFwd_1x1 | 174-176, 183-186, 226, 229-230 | conv_asm_implicit_gemm_fwd_v4r1_dynamic.cpp | n/a | `-S` で指定したsolverのcompile/immediate実行へ進行 |
| SetAsFound1_0 ... ConvAsmImplicitGemmV4R1DynamicFwd_1x1 | 214 | include/miopen/find_solution.hpp | n/a | find 1.0 bestとして登録 |
| Memory access fault by GPU node-1 | 233 | n/a (runtime fault) | n/a | kernel実行時にGPU fault |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: ConvAsmImplicitGemmV4R1DynamicFwd_1x1 (`-S` 強制指定)
- kernel selected: igemm_v4r1_1x1_dynamic_* (log内kernel名)
- dot4 instruction present: unknown (このケースは実行時faultのため別途hsaco確認が必要)
- additional comments: 自然選択ではnaiveが報告されるが、強制指定時はimmediate実行に進んでからGPU memory access faultで停止。