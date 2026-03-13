# rocMLIR 追加フェーズ向け提案（Vega / gfx900 調査接続）

## 0. 目的

本提案は、`rocMLIR` 追加中の現在フェーズで、

1. MIOpen 側の既知失敗シグネチャ（`MIIR_INVALID_PARAM`, `Code object build failed`, `not applicable`）
2. solver family ごとの適用境界（MLIR / CK / HipImplicitGemm）
3. Vega(gfx900) 実機観測

を接続して、次の検証を短サイクルで回すための実行計画を示す。

---

## 1. 現状整理（2026-03-13 時点）

- `rocMLIR` は作業ツリー展開済み（`mlir/tools/rocmlir-lib/Miir.h`, `rocmlir-lib.cpp` を確認）。
- MIOpen 側の接続点は特定済み。
  - `rocm-libraries/projects/miopen/src/mlir_build.cpp`（`MIIR_INVALID_PARAM`）
  - `rocm-libraries/projects/miopen/src/hipoc/hipoc_program.cpp`（`Code object build failed`）
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_ck_igemm_fwd_v6r1_dlops_nchw.cpp`
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_xdlops.cpp`
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_v4r5_xdlops.cpp`
  - `rocm-libraries/projects/miopen/src/fin/fin_interface.cpp`（solver id 80/114/128）
  - `rocm-libraries/projects/miopen/src/include/miopen/conv/solvers.hpp`
- 実機観測では、強制 solver 実行で以下の失敗モードが再現済み。
  - `ConvMlirIgemmFwd`: `MIIR_INVALID_PARAM` -> `rc=0x7`
  - `ConvCkIgemmFwdV6r1DlopsNchw`: `not applicable` -> `rc=0x3`
  - `ConvHipImplicitGemmForwardV4R5Xdlops`: `Code object build failed` -> `rc=0x7`
  - `ConvHipImplicitGemmFwdXdlops`: assertion abort (`EXIT=134`)

---

## 2. 直近ゴール（短期）

### 2.1 解析ゴール

- `rocMLIR` と MIOpen の接続境界を、関数単位で静的に固定する。
- `MIIR_INVALID_PARAM` 発生条件を、shape/dtype/layout 軸で最小再現ケース化する。
- `Code object build failed` を「MLIR生成失敗」か「HIP/LLVMコード生成失敗」かで分離する。

### 2.2 運用ゴール

- 実行ケースごとに `trace_map` と `solver_extract.log` の対応を必ず 1:1 で保持。
- `~/vega_path_check_logs` を単一ソースにし、同期後にのみノート更新する。

---

## 3. 実行計画（3フェーズ）

## フェーズA: 接続点固定（完了）

1. MIOpen 側のアンカー関数を固定する。
   - `mlir_build.cpp`: MIIRステータス変換
   - `solver.cpp` / `fin_interface.cpp`: solver 登録と id 対応
   - 各 solver 実装: `IsApplicable`, `GetSolution`, `Search`
2. `MIIR_INVALID_PARAM` の到達経路を call chain として記録する。
3. `Code object build failed` の throw 点から逆向きに入力ソース生成地点を辿る。

成果物:
- `trace_map_static.md` への「MLIR接続点」節追加
- `solver_architecture_map.md` への solver id 対応追記

## フェーズB: rocMLIR展開後の結線確認（進行中）

1. `rocMLIR` 側で MIOpen から呼ばれる API / エントリを特定する。
2. gfx900 で拒否される条件（arch gate, dtype gate, intrinsic gate）を列挙する。
3. 条件ごとに「MIOpen前段で弾くべきか」「rocMLIR内で graceful fallback すべきか」を分類する。

進捗メモ (2026-03-13):
- `rocmlir-lib` の MIIR C API 実装（`miirCreateHandle`, `miirLowerTuningParams`, `miirLowerBin`, `miirBufferGet`）を確認。
- `miirCreateHandle` の初期 gate として `parseConvConfig` / `isApplicable` / `RockEnabled` を確認。
- `RockEnabled` で layout 制限と `bf16` 拒否（`inputDataTypeStr != "bf16"`）を確認。

成果物:
- `gfx900_related_nodes.md` への `rocMLIR` 節追加
- `support_boundary.md` への責務分担案追記

## フェーズC: 実験再設計（最小反復ループ）

1. 形状固定（3x3, NCHW, n16/c64/k64）で dtype 軸を再走査する。
2. 失敗モードを4分類する。
   - applicability reject (`rc=0x3`)
   - compile fail (`rc=0x7` + code object)
   - MLIR invalid param (`MIIR_INVALID_PARAM`)
   - runtime/assert abort (`EXIT=134`)
3. 各分類ごとに、修正ポイント候補を 1 つだけ置く。

成果物:
- `trace_map_dynamic.md` 更新
- `solver_observation_log.md` 更新
- `hypothesis.md` 更新

---

## 4. 提案する優先順位

1. まずは「観測の意味づけ」を固定する（接続点と失敗分類）。
2. 次に `rocMLIR` 展開後に静的差分を取る（実装を読める状態にする）。
3. 最後に solver 強制実行の再試行を行う（再現性の高いケースのみ）。

理由:
- 先に実験を増やすとログは増えるが、失敗原因が分離できない。
- 先に境界を固定すると、同じ1本のログでも改善余地を特定しやすい。

---

## 5. 具体タスク（チェックリスト）

- [ ] `rocMLIR` の作業ツリーを展開し、読み取り可能状態を確認する
- [ ] MIOpen 側の MLIR 呼び出し経路を `trace_map_static.md` に追記する
- [ ] solver id 80/114/128 の登録点と実装を 1 ページに集約する
- [ ] `MIIR_INVALID_PARAM` の最小再現ケースを 1 つに絞る
- [ ] `Code object build failed` の入力ソース生成地点を特定する
- [ ] 失敗4分類の判定テンプレを `trace_map` ヘッダへ追加する

---

## 6. 完了判定

以下を満たしたら、rocMLIR追加フェーズの提案作業は一旦完了とする。

- `rocMLIR` 境界の静的接続図がある
- 失敗シグネチャごとの責務層（MIOpen/rocMLIR/HIPOC）が分離されている
- 最小再現ケース（1ケース）が次回も同じ分類に入る
