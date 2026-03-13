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
- `ConvGenerator::isApplicable()` は `hasValidDimension()` 中心で、arch 固有拒否は明示されていないことを確認。
- MIOpen 側 `ConvMlirIgemmFwd::IsApplicable()` に `gfx900` 明示拒否（issue #389 コメント付き）があり、
  最小再現ケースは未サポート solver を `-S 98` で強制実行している状態であることを確認。
- 最小再現ケース（`vega64_int8_force_mlir_fwd`）は RockEnabled の layout/dtype 条件には合致しており、失敗要因は別分岐の可能性が高い。
- 参照ソースと `/opt/rocm` 実ランタイムの差分可能性を考慮し、`miirCreateHandle` の最終分岐確定は
  ランタイム実体での追加トレース（引数/分岐ログ）取得を完了条件とする。

追記 (2026-03-13, git blame 調査完了):

### gfx900 除外の provenance 確定

`mlir_common.hpp: IsMlirSupportedHardware()` は `gfx900` を **明示リストに含む**（対応ハードとして認定済み）:
```cpp
// src/include/miopen/solver/mlir_common.hpp:44
c.GetStream().GetDeviceName() == "gfx900"  // gfx900 はここで通る
```
→ MLIR対応ハードとして一度は位置付けられた世代。

それにもかかわらず `conv_mlir_igemm_fwd.cpp` の `IsApplicable()` 内で個別除外:
```cpp
// 186: // Refer to https://github.com/ROCm/llvm-project-private/issues/389
// 187-189:
const auto device_name = ctx.GetStream().GetDeviceName();
if(StartsWith(device_name, "gfx900"))
    return false;
```

**git blame 結果（確定）:**
- `lines 187-189` (除外コード本体): **Zhuoran Yin** (`zhuoryin@amd.com`, AMD) / **2021-12-22** / commit `2407d2f556c7`
  - コミットタイトル: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
  - 元コメント URL: `github.com/ROCmSoftwarePlatform/llvm-project-private/issues/389`
- `line 186` (コメントURL更新): **Artem Tamazov** / **2023-12-13** / commit `b0f912e5244b`
  - タイトル: `[Doc] Fix URLs (ROCmSoftwarePlatform -> ROCm) in the doc, comments, and code.`
  - → org名変更（`ROCmSoftwarePlatform` → `ROCm`）に伴う一括URL修正のみ

**同一パターンが fwd/bwd/wrw すべてに存在** (同一コミット `2407d2f556c7` で一括投入)

### issue #389 の性質

参照先: `ROCm/llvm-project-**private**/issues/389`（非公開リポジトリ）
- 非公開 → AMD社内的な LLVM/AMDGPU コードジェン上のバグ報告
- `MIIR_INVALID_PARAM` が `miirLowerTuningParams` で発生するのはこのバグの症状
- rocMLIR 単体の問題ではなく **LLVM バックエンド（amdgpu codegen）レベルの問題**

### フォーク判断への含意

- MIOpen のフォークだけでは MLIR iGEMM の gfx900 対応は修正不可
- 修正ポイントは `llvm-project`（AMDGPU コードジェン）側にある
- rocMLIR の `isApplicable`/`RockEnabled` は gfx900 自体は拒否していない
  → 問題はさらに下の lowering/codegen 段階
- 代替経路（`ConvHipImplicitGemmV4R1Fwd` 等の ASM 系 solver）は今のままで動作

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
