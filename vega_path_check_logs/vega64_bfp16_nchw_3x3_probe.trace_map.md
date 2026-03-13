# TRACE MAP

- case_id: vega64_bfp16_nchw_3x3_probe
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_bfp16_nchw_3x3_probe.log
- extract: /home/limonene/vega_path_check_logs/vega64_bfp16_nchw_3x3_probe.trace_extract.log

## 2. Key Evidence

- solver selected: 91/GemmFwdRest
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;143:MIOpen(HIP): Info2 [GetSolutions] GemmFwdRest;170:MIOpen(HIP): Info [GetSolutions] ;179:MIOpen(HIP): Info2 [GetSolutions] GemmFwdRest;1208:MIOpen Forward Conv. Algorithm: 0, Solution: 91/GemmFwdRest;

## 3. Decision

- [ ] fallback_confirmed
- [x] fallback_not_confirmed
- [ ] need_more_cases
## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
