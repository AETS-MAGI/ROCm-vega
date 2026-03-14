# Vega(gfx900) / MIOpen / rocMLIR 調査 facts

更新日: 2026-03-14

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

### 4.5 gfx900 MLIR iGEMM 除外の provenance（git blame 確定, code_verified）

- 除外コミット: `2407d2f556c7635de3f4b3f009681bdd92ba82e2`
- 作者: Zhuoran Yin (`zhuoryin@amd.com`, AMD 社員)
- 日付: 2021-12-22
- コミットメッセージ: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
- 対象: FWD / BWD / WRW 全3ファイルを同一コミットで同時除外
  - `conv_mlir_igemm_fwd.cpp:188`
  - `conv_mlir_igemm_bwd.cpp:68`
  - `conv_mlir_igemm_wrw.cpp:69`
- コメント参照先: `// Refer to https://github.com/ROCmSoftwarePlatform/llvm-project-private/issues/389`
  - これは AMD 社内の非公開 LLVM リポジトリ (`llvm-project-private`) の issue
  - 公開リポジトリの `ROCm/MIOpen #389`・`ROCm/rocMLIR #389` とは**無関係**
- URL 修正コミット: `b0f912e5244b`（Artem Tamazov, 2023-12-13）
  - 内容は `ROCmSoftwarePlatform` → `ROCm` 組織名書き換えのみ
  - issue の参照先が非公開であるという事実は変わっていない

**解釈**:

- gfx900 除外は AMD 社員による意図的コミット（コミュニティパッチではない）
- 問題根拠は LLVM/コンパイラバックエンドレベル（MIOpen や rocMLIR 本体の問題ではない）
- `Disable` という動詞は `Remove` より「一時的/バグ回避的な無効化」ニュアンスが強いが、
  private issue の内容が外部から確認不可のため「設計判断 vs バグ回避」は断定不可

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

- 初回失敗: `nlohmann_json` 不足
- 対応: `nlohmann-json` 導入
- 次の失敗: `Could NOT find rocMLIR` / `Could not find LIBMLIRMIOpen`
- 結論

- `/opt/rocm` には `rocMLIRConfig.cmake` / `libMLIRMIOpen` が入っていない
- 先に rocMLIR をローカル install して `rocMLIR_DIR` を渡す必要がある

### 7.2 rocMLIR ビルド

- 初回失敗: `Ninja` 未導入
- 再試行（Unix Makefiles）: 長時間 configure 後に進捗停止/割り込み終了が混在
- 依存対応: `pybind11` 導入
- その後

- configure ログで `Found pybind11` を確認
- 完走前の割り込み (`EXIT:130`) が発生

- 対応

- detached 起動スクリプトを導入し、割り込み耐性を確保
- detached 起動スクリプトの既定 generator を `Unix Makefiles` から `Ninja` に変更
  - 理由: Makefiles 既定では `cmake -G Unix Makefiles` が長時間 configure に留まり、prefix 生成まで進まないケースを観測したため
- workspace 側 `tmp` を build root にすると、生成された `llvm-min-tblgen` 実行で `Permission denied` (`code=126`) となることを確認
  - 原因: この調査ワークスペース配下は noexec 相当の制約があり、rocMLIR/LLVM ビルド中に生成される補助実行ファイルを実行できない
  - 対応: detached 起動スクリプトの既定 `ROCMLIR_BUILD_ROOT` を workspace `tmp/` から `/tmp/` に変更

---

## 8. 現在ステータス（2026-03-14 更新）

### 確定済み（code_verified）

- [x] MLIR iGEMM FWD/BWD/WRW の gfx900 除外コード確認
- [x] ASM v4r1 dynamic / Winograd / DLOPS 登録の gfx900 生存確認
- [x] rocBLAS/CK/Tensile の二段フォールバック・dot4代替確認
- [x] git blame で gfx900 MLIR 除外コミット `2407d2f` を確定（Zhuoran Yin, AMD, 2021-12-22, PR #1328）
- [x] `#389` が `llvm-project-private`（AMD 社内非公開）の issue であり、公開リポジトリの同番号とは無関係と確定
- [x] `IsMlirSupportedHardware()` に gfx900 は含まれるが、`ConvMlirIgemm{Fwd,Bwd,Wrw}::IsApplicable()` で後段除外される二重構造を確認
- [x] gfx900 用の tuning パラメータが Perf DB に不在（`Perf Db: record not found`）

### 確定済み（runtime_verified）

- [x] FP32 自然選択で `ConvBinWinograd3x3U` / `ConvAsm1x1U` / `ConvHipImplicitGemmV4R1Fwd` が動作
- [x] MLIR iGEMM 強制実行: `MIIR_INVALID_PARAM (rc=0x7)`
- [x] DLOPS グリッド15ケース以上: 全件 `not applicable (rc=0x3)`
- [x] XDLops 強制: build 失敗 / assertion abort
- [x] MLIR iGEMM `-S` 強制で `IsApplicable` バイパス → `CompileSolution` → `GetInvoker` まで到達 → Perf DB 不在 → `boost::optional::get()` assert crash（INT8/FP32 両方）
- [x] ローカル Debug MIOpen (MLIR=Off) ビルド成功、FP32 conv 正常動作確認

### 確定済み（build_verified）

- [x] CIFS マウント上のソースで cmake configure → 12時間以上 D-state ハング
- [x] WD-Black NVMe ローカル clone → cmake configure 7.5〜9.6秒で完了
- [x] CK (Composable Kernel) は `v_fmac_f32` 命令を使用 → gfx900 非対応（gfx906+）
- [x] システム GCC は `--offload-arch=gfx900` を認識しない → `/opt/rocm/llvm/bin/clang++` が必須
- [x] half 2.2.x では `half_float::detail::expr` 型が削除されている → パッチ必要

### 未解決・未完了

| 項目 | 状態 |
|---|---|
| ~~rocMLIR Ninja ビルド完走~~ | 回避済み（MLIR=Off で MIOpen ビルド成功） |
| ~~MIOpen debug ビルド~~ | **完了**（WD-Black NVMe, 2026-03-14） |
| ~~`miirCreateHandle` の `nullptr` 分岐最終確定~~ | 代替確認済み（システム MIOpen で失敗メカニズム確定） |
| MLIR 有効 Debug ビルド | 未着手（rocMLIR 再ビルドが前提。失敗メカニズムは確定済みのため優先度低） |
| INT8 非 naive solver 自然選択 | 未達成（全形状で `ConvDirectNaiveConvFwd` のみ） |
| MIOpen PR #1328 レビューコメント | 未確認（GitHub: `ROCm/MIOpen/pull/1328`） |
| 公開 `llvm-project` での同系統 issue 照合 | 未着手 |

---

## 9. 未解決事項（詳細）

- **未解決1**: rocMLIR build/install の完走確認
  - build root を workspace `tmp/` から `/tmp/` に変更した（`noexec` 制約回避）
  - `rocMLIRConfig.cmake` 生成確認コマンド: `ls tmp/rocmlir-prefix-*/lib/cmake/rocMLIR/rocMLIRConfig.cmake 2>/dev/null`

- **未解決2**: MIOpen debug ビルド成功確認（`rocMLIR_DIR` 解決状態）
  - `ROCMLIR_PREFIX=<prefix> bash tools/build_miopen_debug_local.sh`

- **未解決3**: `miirCreateHandle` の `nullptr` 分岐を runtime ログで最終確定
  - 有力仮説: `parseConvConfig` での失敗
  - 確定方法: `mlir_build.cpp` に一時ログを追加 → ローカル debug ビルドで再実行

---

## 10. 次に実行すべき最短手順

**パスA（debug ビルド路線）**

```bash
# rocMLIR ビルド完走確認
ls tmp/rocmlir-prefix-*/lib/cmake/rocMLIR/rocMLIRConfig.cmake

# MIOpen debug 再ビルド
ROCMLIR_PREFIX=<detached prefix> bash tools/build_miopen_debug_local.sh

# local runtime でケース再実行
bash tools/run_case_with_local_miopen.sh vega64_int8_force_mlir_fwd_local_dbg
```

**パスB（履歴・外部調査路線）**

```bash
# MIOpen PR #1328 レビューコメント確認
gh pr view 1328 --repo ROCm/MIOpen --comments

# 公開 llvm-project での gfx900/MLIR issue 探索
gh search issues --repo llvm/llvm-project "gfx900 MLIR" --state all
```

- local runtime でケース再実行

  `run_case_with_local_miopen.sh` で `vega64_int8_force_mlir_fwd_local_dbg`

- 必要なら `src/mlir_build.cpp` に一時ログを入れて handle/status を採取

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

- 除外コミット: `2407d2f`
- 作者: Zhuoran Yin (`zhuoryin@amd.com`)
- 日付: 2021-12-22
- コミットメッセージ: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
- 対象ファイル: FWD / BWD / WRW の全3ファイル同時

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
