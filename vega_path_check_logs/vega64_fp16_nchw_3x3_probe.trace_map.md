# TRACE MAP

- case_id: vega64_fp16_nchw_3x3_probe
- status: fallback_not_confirmed

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp16_nchw_3x3_probe.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp16_nchw_3x3_probe.trace_extract.log

## 2. Key Evidence

- solver selected: 11/ConvOclDirectFwd
- lines: 124:MIOpen(HIP): Info [GetSolutions] ;147:MIOpen(HIP): Info2 [GetSolutions] ConvOclDirectFwd;173:MIOpen(HIP): Info [GetSolutions] ;185:MIOpen(HIP): Info2 [GetSolutions] ConvOclDirectFwd;413:MIOpen Forward Conv. Algorithm: 1, Solution: 11/ConvOclDirectFwd;

## 3. Decision

- [ ] fallback_confirmed
- [x] fallback_not_confirmed
- [ ] need_more_cases
## 4. Notes

- kernel selected: see log/solver_extract
- dot4 instruction present: n/a
- additional comments: auto-merged from runtime logs.
