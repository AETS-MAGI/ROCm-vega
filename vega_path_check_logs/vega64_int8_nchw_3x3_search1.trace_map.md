# TRACE MAP

- case_id: vega64_int8_nchw_3x3_search1
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_nchw_3x3_search1.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_nchw_3x3_search1.trace_extract.log

## 2. Key Evidence

- solver selected: 85/ConvDirectNaiveConvFwd
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;143:MIOpen(HIP): Info2 [GetSolutions] ConvDirectNaiveConvFwd;169:MIOpen(HIP): Info [GetSolutions] ;178:MIOpen(HIP): Info2 [GetSolutions] ConvDirectNaiveConvFwd;395:MIOpen Forward Conv. Algorithm: 1, Solution: 85/ConvDirectNaiveConvFwd;

## 3. Decision

- [fallback_not_confirmed] fallback_confirmed
- [x] fallback_not_confirmed
- [fallback_not_confirmed] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
