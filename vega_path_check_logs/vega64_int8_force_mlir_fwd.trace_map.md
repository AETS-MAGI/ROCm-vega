# TRACE MAP TEMPLATE

- case_id: vega64_int8_force_mlir_fwd
- status: need_more_cases

## 1. Observed Lines

- log: /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.log
- extract: /home/limonene/vega_path_check_logs/vega64_int8_force_mlir_fwd.trace_extract.log

## 2. Log-to-Source Mapping

| Observed log line | Log line number | Source file | Source line | Interpretation |
|---|---:|---|---:|---|
| GetSolutions: ConvDirectNaiveConvFwd | 164-166 | n/a (runtime selection result) | n/a | library report上はnaiveが候補 |
| Warning: Solution id (98) is not reported by the library. Trying it anyway... | 167 | n/a (MIOpenDriver message) | n/a | `-S` 強制指定で未報告solverを試行 |
| solver_id = ConvMlirIgemmFwd | 176, 185-187 | mlir build / solver path | n/a | `GetForwardSolutionWorkspaceSize` -> `CompileSolution` -> `FindSolutionImpl` に進行 |
| Perf Db: record not found for: ConvMlirIgemmFwd | 206 | n/a (runtime DB state) | n/a | 対応するperf record未取得 |
| miirLowerTuningParams MIIR_INVALID_PARAM | 207 | src/mlir_build.cpp | 59 | MLIR loweringパラメータ不正で失敗 |
| RunForwardGPU() FAILED, rc = 0x7 | 208 | MIOpenDriver runtime | n/a | forward実行失敗を直接観測 |
| __EXIT_CODE=7 | 246 | shell wrapper | n/a | コマンド失敗コードを保持 |

## 3. Decision

- [ ] fallback_confirmed
- [ ] fallback_not_confirmed
- [x] need_more_cases

## 4. Notes

- solver selected: ConvMlirIgemmFwd (`-S` 強制指定)
- kernel selected: n/a (MLIR lowering失敗のためkernel launch前に停止)
- dot4 instruction present: n/a
- additional comments: 自然選択はnaiveだが、強制時はMLIR solver経路へ進んだ後に `MIIR_INVALID_PARAM` で失敗。
