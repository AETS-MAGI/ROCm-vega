# TRACE MAP

- case_id: vega64_fp32_nchw_group2_3x3
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp32_nchw_group2_3x3.trace_extract.log

## 2. Key Evidence

- solver selected: 53/ConvBinWinogradRxSf2x3
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;151:MIOpen(HIP): Info2 [GetSolutionsFallback] Using WTI Fallback;152:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvBinWinogradRxSf3x2 Estimated WTI = -2;153:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvBinWinogradRxSf2x3 Estimated WTI = -2;154:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvDirectNaiveConvFwd Estimated WTI = 0.01;155:MIOpen(HIP): Info2 [GetSolutionsFallback] GemmFwdRest Estimated WTI = 0.24624;156:MIOpen(HIP): Info2 [GetSolutionsFallback] maxSolutionCount = 1, available = 2;157:MIOpen(HIP): Info2 [GetSolutionsFallback] id: 85, algo: 1, time: 1000, ws: 0, name: ConvDirectNaiveConvFwd;158:MIOpen(HIP): Info2 [GetSolutionsFallback] id: 91, algo: 0, time: 40.6108, ws: 7225344, name: GemmFwdRest;254:MIOpen(HIP): Info [GetSolutions] ;271:MIOpen(HIP): Info2 [GetSolutionsFallback] Using WTI Fallback;272:MIOpen(HIP): Info2 [GetSolutionsFallback] ConvBinWinogradRxSf3x2 Estimated WTI = -2;

## 3. Decision

- [fallback_not_confirmed] fallback_confirmed
- [x] fallback_not_confirmed
- [fallback_not_confirmed] need_more_cases

## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
