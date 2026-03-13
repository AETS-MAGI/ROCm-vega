# TRACE MAP

- case_id: vega64_fp16_force_hipigemm_fwdxdlops_nchw_3x3
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_fp16_force_hipigemm_fwdxdlops_nchw_3x3.log
- extract: /home/limonene/vega_path_check_logs/vega64_fp16_force_hipigemm_fwdxdlops_nchw_3x3.trace_extract.log

## 2. Key Evidence

- solver_id: ConvHipImplicitGemmFwdXdlops
- outcome: assertion abort
- lines: 218:/usr/lib64/gcc/x86_64-pc-linux-gnu/15.2.1/../../../../include/c++/15.2.1/bits/stl_vector.h:1263: reference std::vector<std::basic_string<char>>::operator[](size_type): Assertion '__n < this->size()' failed.;220:__EXIT_CODE=134;

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases
## 4. Notes

- solver selected: ConvHipImplicitGemmFwdXdlops
- kernel selected: n/a (forced solver path)
- dot4 instruction present: n/a
- additional comments: Forced HipImplicitGemm Xdlops probe for dtype-axis comparison.
