# TRACE MAP

- case_id: vega64_int8_force_dlops_ck
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_dlops_ck.trace_extract.log

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| `solution_id = 114` | 174 | n/a (runtime selection) | n/a | 強制指定した solution id が採用された。 |
| `solver_id = ConvCkIgemmFwdV6r1DlopsNchw` | 176 | n/a (runtime selection) | n/a | CK DLOPS solver の workspace 判定フェーズに進行。 |
| `The supplied solution id ... is not applicable to the current problem` | 177 | `src/ocl/convolutionocl.cpp` | 1057 | このproblem設定では CK DLOPS solver が適用不可。 |
| `RunForwardGPU() FAILED, rc = 0x3` | 178 | n/a | n/a | 適用不可により forward 実行失敗で終了。 |
| `__EXIT_CODE=3` | 216 | n/a | n/a | ラップ実行での最終終了コード。 |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: 強制指定 `ConvCkIgemmFwdV6r1DlopsNchw`（solution_id=114）
- kernel selected: 実行前に適用不可判定となり未到達
- dot4 instruction present: n/a
- additional comments: 同系列のグリッド実験でも `not applicable` / `rc=0x3` が一貫しており、成立条件は未特定。
