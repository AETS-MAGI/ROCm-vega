# TRACE MAP TEMPLATE

- case_id: vega64_int8_force_dlops_ck
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.trace_extract.log

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| GetSolutions: ConvDirectNaiveConvFwd | 164-166 | n/a (runtime selection result) | n/a | library report上はnaiveが候補 |
| Warning: Solution id (114) is not reported by the library. Trying it anyway... | 167 | n/a (MIOpenDriver message) | n/a | `-S` 強制指定で未報告solverを試行 |
| solver_id = ConvCkIgemmFwdV6r1DlopsNchw | 176 | n/a (runtime log) | n/a | DLOPS solverに進もうとした痕跡 |
| supplied solution id ... is not applicable to the current problem | 177 | src/ocl/convolutionocl.cpp | 1057 | 当該問題に対してsolver適用不可 |
| RunForwardGPU() FAILED, rc = 0x3 | 178 | MIOpenDriver runtime | n/a | 実行失敗を直接観測 |
| __EXIT_CODE=3 | 216 | shell wrapper | n/a | コマンド失敗コードを保持 |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: ConvCkIgemmFwdV6r1DlopsNchw (`-S` 強制指定)
- kernel selected: n/a (not applicableでkernel launch前に停止)
- dot4 instruction present: n/a
- additional comments: INT8 3x3 NCHW条件ではDLOPS solverは適用不可。DLOPS成立条件の切り分けは継続。
