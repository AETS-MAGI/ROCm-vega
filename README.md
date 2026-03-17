# vega investigations index

このディレクトリは、`gfx900` / Vega を入口にしつつ、
ROCm の実行経路・GitHub 履歴・設計モデルを並行して追う investigation notebook です。

## 0. 現時点の調査状態（2026-03-15）

「gfx900 がなぜ半分死んで半分生きているか」の構造把握はほぼ完了。根本の見えない部分だけが細く残っている段階。

### 確定済み

- MLIR iGEMM 除外: commit `2407d2f`（Zhuoran Yin, AMD, 2021-12-22）で明示 disable。`IsMlirSupportedHardware()` には gfx900 が残るのに個別 solver 側で後段除外される二重構造も code_verified。
- 実機: MLIR 強制実行で CompileSolution → GetInvoker まで進むが Perf DB 不在 → `boost::optional::get()` assertion crash。gfx900 での MLIR 経路が実用不能は runtime_verified。
- FP32 自然選択: `ConvBinWinograd3x3U` / `ConvAsm1x1U` / `ConvHipImplicitGemmV4R1Fwd` が動作確認済み（旧経路・fallback 側は生きている）。
- INT8: 追加探索でも自然選択は全件 `ConvDirectNaiveConvFwd` のみ。非 naive INT8 solver の自然選択は未達成確定寄り。
- rocMLIR: public `ROCm/rocMLIR` で `miirCreateHandle` → `parseConvConfig` → `isApplicable` → `RockEnabled` まで追跡可能と確認。
- ビルド: CIFS 回避、WD-Black NVMe 上で MIOpen debug build 成功（MLIR=Off, CK=Off, AI=Off 構成）。
- 文書: MD/HTML 全体の中立化（ディスクレーマー・Non-claims・Fact/Interpretation/Open Question）完了。

### 残タスク

1. MLIR 有効 Debug build での内部ログ採取（失敗メカニズム自体は固まっているため優先度低）
2. `provenance_map.md` の拡張（誰が入れたかの先に「誰が残し・運用し・直せるか」を地図化する）
3. `MIIR_BUILD_FAILURE` を出す具体ケースの実機再現（現在は `MIIR_INVALID_PARAM` と Perf DB crash まで確認済み）

---

## 1. 運用方針

- 推論経路の最終判定は生コードを真実源とする。
- 公開一次資料、ローカル clone、実機ログ、逆アセンブルを優先する。
- 参考リサーチは補助情報として扱い、未照合情報は結論根拠に使わない。
- 文体と断定範囲は `AGENTS.md` に従う。
- investigation 文書（`.md`）を修正したら、対応する public HTML にも反映する。
- **図の使用方針**: 「層」「分岐」「fallback」「主体の分解」のような構造は Mermaid 図で示す。HTML ページには `https://cdn.jsdelivr.net/npm/mermaid@11` を CDN で読み込み `<div class="mermaid">` ブロックを使用する。1ページあたり 2–3 図を上限の目安とし、テキストの補助として機能させる。図のラベルは英語を基本とし、周囲の日英両語テキストが文脈を提供する。

## 2. まず読む順番

### 実行経路と事実を先に押さえる

- `vega-rocm.md`
  - 推論経路トレース本体。MIOpen / rocBLAS / CK / Tensile の code path を扱う。
- `facts.md`
  - code / runtime / history ごとに確認済み事項を固定する fact ledger。
- `work_logs.md`
  - 何を見て、どこまで進んだかの作業時系列。

### 次に歴史と仮説を読む

- `rocm-github-investigate.md`
  - GitHub 履歴・release block・legacy repo から見る `gfx900` 変遷。
- `reveal_hypothesis.md`
  - `gfx900` から見えてきた ROCm 一般の設計モデル。
- `hypothesis.md`
  - `gfx900` を中心に置いた仮説整理と検証状況。

### ROCm 全体の構造を読む

- `design_philosophy.md`
  - `ROCm` / `TheRock` / `rocm-systems` の一次資料から、ROCm をどういう stack と読めるかを固定する。
- `abstraction_layers.md`
  - integration / runtime / selection / codegen / distribution の層に分けて、`gfx900` 観測点がどこに乗るかを整理する。
- `fallback_chain_map.md`
  - MIOpen / rocBLAS / Tensile / TheRock にまたがる fallback / gating / selective exclude を一枚で整理する。
- `gfx900_related_nodes.md`
  - `gfx900` が normalize / gate / select / catalog / ship のどこに現れるかを層別ノードとして固定する。

### 実行・再現用の補助

- `disassemble_rocm.md`
- `miir_runtime_trace.md`
- `miopen_debug_rebuild_plan.md`
- `trace_map_static.md`
- `trace_map_dynamic.md`
- `rocmlir_integration_proposal.md`

## 3. 役割別ドキュメント一覧

### 根拠文書

- 推論経路トレース本体: `vega-rocm.md`
- 事実台帳: `facts.md`
- 作業ログ: `work_logs.md`
- GitHub 履歴調査: `rocm-github-investigate.md`
- ROCm 一般の GitHub 調査: `rocm-common-investigate_github.md`
- GitHub 側から見た一般設計思想検証: `reveal_hypothesis.md`
- ROCm 設計傾向の固定: `design_philosophy.md`
- ROCm 層構造の整理: `abstraction_layers.md`
- cross-component fallback 地図: `fallback_chain_map.md`
- `gfx900` 関連ノード索引: `gfx900_related_nodes.md`
- 仮説整理: `hypothesis.md`
- 経路別主体 Provenance Map: `provenance_map.md`

### 実行・ビルド補助

- 実行補助スクリプト: `run_vega_path_case.sh`
- MIIR トレース補助: `run_vega_path_case_miir_trace.sh`
- ローカル rocMLIR ビルド: `tools/build_rocmlir_local.sh`
- ローカル rocMLIR ビルド（detached 起動）: `tools/start_rocmlir_build_detached.sh`
- ローカル MIOpen 差し替え実行: `tools/run_case_with_local_miopen.sh`
- ローカル Debug 版 MIOpen ビルド: `tools/build_miopen_debug_local.sh`

### 補助メモ

- 逆アセンブル手順: `disassemble_rocm.md`
- MIIR runtime trace: `miir_runtime_trace.md`
- 再ビルド手順メモ: `miopen_debug_rebuild_plan.md`
- trace map: `trace_map_static.md`, `trace_map_dynamic.md`

## 4. 調査対象ソースセット

### 現行 official clone

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/`

### retired / legacy repo 群

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/`

### 現時点での一次対象

- `MIOpen`
- `Tensile`
- `ROCR-Runtime`

### 補助対象

- `ROCm/vllm`
  - ROCm 固有 fork / 運用層の歴史としては有益だが、`gfx900` 推論経路本体とは一段離れるため別枠で扱う。

### 注記

- retired repo の README にある移行先案内（`rocm-libraries`, `rocm-systems`, upstream 等）は、repo topology 再編の一次資料として扱う。
- legacy / retired repo の late activity は、中身の policy 変更と layout/docs 再編を分けて読む。

## 5. 監査ラベル

- `code verified`
  - 生コードで分岐や条件を確認済み。
- `runtime verified`
  - 実機実行やログ採取で動作・失敗モードを確認済み。
- `history verified`
  - `git blame` / `git log` / changelog / PR metadata など履歴情報で確認済み。
- `hypothesis`
  - 観測を踏まえた解釈・推論。未確定を含む。
- `hint only`
  - 参考情報のみでコード未確認。
- `out of scope`
  - この調査の主題外。

詳細な仕分け表は `vega-rocm.md` の第15節を参照。

## 6. 参考リサーチ吸収メモ（非推論経路）

以下は旧 Gemini リサーチ文書から移した背景メモであり、コード未照合の項目を含む。
この節は結論の根拠には使わない。

### 6.1 エコシステム背景

- ROCm 7.2 以降は新世代アーキテクチャへの最適化比重が高い。
- 旧世代を含む運用では、公式サポートとコミュニティ運用の間にギャップが出やすい。

### 6.2 RDNA 系の観測ポイント（背景）

- RDNA4 系はネイティブ最適化の対象として扱われる一方、初期運用で個別不具合報告がある。
- RDNA2 系ではソフトウェア的な代替経路や最適化が議論されるが、本ノートでは背景情報扱い。

### 6.3 MIGraphX や上位フレームワークの位置づけ

- 上位レイヤーの設定や EP 選択は重要だが、本調査ワークツリーでは未監査領域がある。
- 実証には当該リポジトリの追加監査が必要。

### 6.4 科学計算系スタック

- LAMMPS/GROMACS などの経路情報は有益だが、本調査の主題である `gfx900` 推論経路とは分離する。
- 必要時は別ノートを作成し、推論経路ノートに混在させない。
