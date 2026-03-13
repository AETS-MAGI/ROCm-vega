# TRACE MAP

- case_id: vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3
- status: need_more_cases

## 1. Observed Lines

- log: vega_path_check_logs/vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3.log
- extract: vega_path_check_logs/vega64_int8_force_hipigemm_fwdxdlops_nchw_3x3.trace_extract.log

## 2. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 3. Notes

- solver selected: see solver_extract
- kernel selected: n/a (forced solver path)
- dot4 instruction present: n/a
- additional comments: forced HipImplicitGemm family probing on Vega64 INT8.
