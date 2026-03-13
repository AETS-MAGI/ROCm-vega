# Vega(gfx900) / MIOpen / rocMLIR 調査 facts

更新日: 2026-03-13

## 1. この文書の目的

この文書は、今回の調査で確認できた事実を時系列と論点別に固定するためのもの。
推測は最小化し、再実行可能な観測とコード参照を優先する。

---

## 2. 調査の主目的

- `-S ConvMlirIgemmFwd` 強制実行時の `MIIR_INVALID_PARAM` 根因を、`miirCreateHandle` 失敗分岐レベルまで確定する。
- runtime 実体（`/opt/rocm` またはローカル debug 置換）で分岐ログを採取できる状態を作る。
- `nullptr` 失敗がどの分岐（`parseConvConfig` / `isApplicable` / `RockEnabled` / `genConvModule` 等）か説明可能にする。

---

## 3. 環境と前提

- OS: EndeavourOS (Linux)
- GPU: AMD Radeon RX Vega (gfx900)
- 主対象 runtime: `/opt/rocm/lib/libMIOpen.so.1.0`
- 参照ソース:
- `tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo/rocm-libraries/projects/miopen`
- `tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo/rocMLIR`
- 重要前提:
- 参照ソースと `/opt/rocm` 実体は完全一致とは限らない。
- この調査ディレクトリでは実行ビットが効かない挙動があるため、補助スクリプトは `bash ./tools/...` で実行する。

---

## 4. 静的解析で確定した事実

### 4.1 MIOpen 側 solver / ID

- `fin_interface.cpp` の強制指定 ID 対応:
- `98/99/100`: `ConvMlirIgemmFwd/Bwd/WrW`
- `80`: `ConvHipImplicitGemmForwardV4R5Xdlops`
- `114`: `ConvCkIgemmFwdV6r1DlopsNchw`
- `128`: `ConvHipImplicitGemmFwdXdlops`

### 4.2 `ConvMlirIgemmFwd` の gfx900 gate

- `conv_mlir_igemm_fwd.cpp` の `IsApplicable()` に `gfx900` 明示拒否分岐がある。
- Vega64(gfx900) では通常探索経路で `ConvMlirIgemmFwd` は候補外。
- `-S 98` は「通常候補外 solver の強制実行」に相当する。

### 4.3 MIIR 境界 (MIOpen -> rocMLIR)

- MIOpen 側:
- `mlir_build.cpp` の `check_miir_error()` が `MIIR_INVALID_PARAM` を例外化。
- rocMLIR 側:
- `rocmlir-lib.cpp` の `miirCreateHandle` は失敗時 `nullptr` を返す設計。
- 代表失敗ポイントは `parseConvConfig`, `isApplicable`, `RockEnabled`, 以降 lower/gen 経路。

### 4.4 `RockEnabled` / `isApplicable` の読み取り

- `RockEnabled` 側は layout と dtype (`bf16` reject) を見る。
- `ConvGenerator::isApplicable()` は主に次元整合性（`hasValidDimension`）で、arch 固有 reject を明示していない。

---

## 5. runtime 観測で確定した事実

### 5.1 強制実行系

- `-S ConvMlirIgemmFwd`
- `miirLowerTuningParams MIIR_INVALID_PARAM`
- `RunForwardGPU() FAILED, rc = 0x7`
- `-S ConvCkIgemmFwdV6r1DlopsNchw`
- `not applicable to the current problem`
- `rc = 0x3`
- `-S ConvHipImplicitGemmForwardV4R5Xdlops`
- code object build failure
- `rc = 0x7`
- `-S ConvHipImplicitGemmFwdXdlops`
- assertion abort (`EXIT=134`)

### 5.2 DLOPS 追加グリッド探索

- `ConvCkIgemmFwdV6r1DlopsNchw` の複数グリッド（NCHW/NHWC, 1x1/3x3, n/c/k/group/stride 変化）で全件 `not applicable` を観測。

### 5.3 LD_PRELOAD フック結果

- 追加物: `run_vega_path_case_miir_trace.sh`, `tools/miir_preload_trace.c`
- ケース自体は `MIIR_INVALID_PARAM` で再現。
- 期待した `[MIIR_TRACE]` がログに出ない。
- 補助確認で `libMIOpen.so` に `miopen::Miir*` は見えるが `miir*` C API シンボルは見えない。
- 結論: 現行 LD_PRELOAD フック方式では MIIR 呼び出しを捕捉できない。

---

## 6. ここまでに追加・更新した実行物

### 6.1 実行・トレース補助

- `run_vega_path_case.sh`
- `run_vega_path_case_miir_trace.sh`
- `tools/miir_preload_trace.c`
- `tools/run_case_with_local_miopen.sh`

### 6.2 ビルド補助

- `tools/build_miopen_debug_local.sh`
- `ROCMLIR_PREFIX` / `rocMLIR_DIR` を受け取れるよう拡張
- `tools/build_rocmlir_local.sh`
- `BUILD_FAT_LIBROCKCOMPILER=On` 等の軽量化フラグを導入
- `tools/start_rocmlir_build_detached.sh`
- `nohup` で割り込み耐性付き起動

### 6.3 ドキュメント

- `miir_runtime_trace.md`
- `miopen_debug_rebuild_plan.md`
- `trace_map_static.md`
- `rocmlir_integration_proposal.md`
- `README.md`
- `TODO.md`

---

## 7. ビルド試行履歴（要点）

### 7.1 MIOpen debug ビルド

1. 初回失敗: `nlohmann_json` 不足
2. 対応: `nlohmann-json` 導入
3. 次の失敗: `Could NOT find rocMLIR` / `Could not find LIBMLIRMIOpen`
4. 結論:
- `/opt/rocm` には `rocMLIRConfig.cmake` / `libMLIRMIOpen` が入っていない
- 先に rocMLIR をローカル install して `rocMLIR_DIR` を渡す必要がある

### 7.2 rocMLIR ビルド

1. 初回失敗: `Ninja` 未導入
2. 再試行（Unix Makefiles）: 長時間 configure 後に進捗停止/割り込み終了が混在
3. 依存対応: `pybind11` 導入
4. その後:
- configure ログで `Found pybind11` を確認
- 完走前の割り込み (`EXIT:130`) が発生
5. 対応:
- detached 起動スクリプトを導入し、割り込み耐性を確保

---

## 8. 現在ステータス（この更新時点）

- `pybind11` は導入済み、rocMLIR configure で認識済み。
- detached rocMLIR ビルドを起動済み。
- PID: `594488`
- ログ: `tmp/rocmlir_build_detached_20260313_165759.log`
- Prefix: `tmp/rocmlir-prefix-detached-20260313_165759`
- 未確認:
- `rocMLIRConfig.cmake` 生成完了
- MIOpen debug ビルド再開
- `vega64_int8_force_mlir_fwd` の local-runtime 再実行
- `src/mlir_build.cpp` 一時ログで分岐最終確定

---

## 9. 未解決事項

- 未解決1: rocMLIR build/install の完走確認
- 未解決2: MIOpen debug ビルド成功確認（`rocMLIR_DIR` 解決状態）
- 未解決3: `miirCreateHandle` の `nullptr` 分岐を runtime ログで最終確定

---

## 10. 次に実行すべき最短手順

1. detached rocMLIR ログ監視
- `tail -f tmp/rocmlir_build_detached_20260313_165759.log`
2. 生成物確認
- `tmp/rocmlir-prefix-detached-20260313_165759/lib/cmake/rocMLIR/rocMLIRConfig.cmake`
3. MIOpen debug 再ビルド
- `ROCMLIR_PREFIX=<detached prefix>` を `build_miopen_debug_local.sh` に渡す
4. local runtime でケース再実行
- `run_case_with_local_miopen.sh` で `vega64_int8_force_mlir_fwd_local_dbg`
5. 必要なら `src/mlir_build.cpp` に一時ログを入れて handle/status を採取

---

## 11. 補足（解釈上の重要点）

- `ConvMlirIgemmFwd` の gfx900 gate があるため、`-S 98` の失敗は「通常非適用 solver を強制した時の失敗」として扱う。
- ただし最終目的は「強制時にどの分岐で落ちるか」の確定であり、未サポート確認だけでは完了ではない。
- 参照ソースと `/opt/rocm` 実体差分の可能性があるため、最終結論は runtime 観測を優先する。

---

## 12. 追加報告（ユーザー提供メモ）

この節は、2026-03-13 にユーザーから追記依頼された内容をそのまま facts として保存する。
（ワークスペース内で `MEMORY.md` ファイル自体は確認できなかったため、本文はユーザー貼り付け内容を出典とする。）

### 12.1 生テキスト

んにゃああああああ

### 12.2 発見まとめ（gfx900 MLIR除外の経路）

| 項目 | 内容 |
|---|---|
| 除外コミット | `2407d2f` |
| 作者 | Zhuoran Yin (`zhuoryin@amd.com`) |
| 日付 | 2021-12-22 |
| コミットメッセージ | `[MLIR] Disable gfx900 from non-xdlops solver (#1328)` |
| 対象ファイル | FWD / BWD / WRW の全3ファイル同時 |

### 12.3 「#389 探し」が空振りだった理由

- コード中コメントの issue 参照先は `llvm-project-private`（AMD private repo）の issue `#389`。
- これは公開 `ROCm/MIOpen` や `ROCm/rocMLIR` の `#389` とは別物。
- 2023年の URL 修正コミット（`b0f912e`）は `ROCmSoftwarePlatform` から `ROCm` への組織名書き換えのみで、参照先 issue の公開/非公開属性は変わっていない。

### 12.4 構造的に判明した点（ユーザー整理）

- 「設計上切った」か「既知バグ回避か」は private issue 本文が読めないため断定不可。
- ただしメッセージ `Disable gfx900 from non-xdlops solver` は、`remove` や `non-support` よりも「一時的/実務的な無効化（バグ回避）」のニュアンスが強い。
- 問題起点は MIOpen 単体より、LLVM/MLIR コンパイラ側制約を示唆する。

### 12.5 次の探索先（ユーザー提案）

- 公開 `llvm-project` で gfx900 / MLIR 関連の commit / issue を再探索し、private #389 と同系統の痕跡がないか確認する。
- MIOpen PR `#1328` のレビューコメントで追加背景情報を確認する。
- `MiirIsConfigApplicable` の内部チェックを掘り、MLIRライブラリ側の制約を直接確認する。
