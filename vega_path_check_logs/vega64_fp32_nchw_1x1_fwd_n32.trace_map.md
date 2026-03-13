# TRACE MAP

- case_id: vega64_fp32_nchw_1x1_fwd_n32
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_1x1_fwd_n32.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_1x1_fwd_n32.trace_extract.log

## 2. Key Evidence

- solver selected: 2/ConvAsm1x1U
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;146:MIOpen(HIP): Info2 [GetSolutions] ConvAsm1x1U;172:MIOpen(HIP): Info [GetSolutions] ;184:MIOpen(HIP): Info2 [GetSolutions] ConvAsm1x1U;427:MIOpen Forward Conv. Algorithm: 1, Solution: 2/ConvAsm1x1U;

## 3. Decision

- [fallback_not_confirmed] fallback_confirmed
- [x] fallback_not_confirmed
- [fallback_not_confirmed] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
