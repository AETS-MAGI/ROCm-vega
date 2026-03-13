# TRACE MAP

- case_id: vega64_fp32_nchw_3x3_s2_k128
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_s2_k128.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_3x3_s2_k128.trace_extract.log

## 2. Key Evidence

- solver selected: 26/ConvHipImplicitGemmV4R1Fwd
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;146:MIOpen(HIP): Info2 [GetSolutions] ConvHipImplicitGemmV4R1Fwd;172:MIOpen(HIP): Info [GetSolutions] ;184:MIOpen(HIP): Info2 [GetSolutions] ConvHipImplicitGemmV4R1Fwd;422:MIOpen Forward Conv. Algorithm: 5, Solution: 26/ConvHipImplicitGemmV4R1Fwd;

## 3. Decision

- [ ] fallback_confirmed
- [x] fallback_not_confirmed
- [ ] need_more_cases
## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
