# gfx900 で拡張・修正可能な層

作成日: 2026-03-17
関連文書: `support_boundary.md`, `final_hypothesis.md §4 Q3`, `community_vs_vendor_matrix.md`, `what_cannot_be_extended.md`（対文書）

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

gfx900 (Vega) において、コミュニティが技術的・法的に手を入れることが可能な層を、
**観測根拠とともに** 整理する。

「拡張・修正可能」の定義: 公開 OSS ソースへのアクセスがあり、原理的にコード変更が成立し、
AMD の内部プロセス（private issue、非公開 CI 等）に依存しない変更として実施できること。

「実際にやりきれるか」（コスト・時間・スキル）は別問題であり、この文書は技術的可能性を記述する。

対文書 `what_cannot_be_extended.md` は「変更できない層」を扱う。

---

## 拡張・修正可能な層（観測ベース）

### 1. MIOpen solver の IsApplicable() 条件

**内容**: 各 solver の `IsApplicable()` は solver ファイル単位で定義されており、
arch / dtype / layout の条件をソースレベルで変更できる。

**観測根拠（code_verified）**:

| solver | 関係ファイル | 変更可能な条件 |
|---|---|---|
| `ConvAsmImplicitGemmV4R1DynamicFwd` | `conv_asm_implicit_gemm_v4r1_dynamic.cpp` | dtype gate（INT8 追加）、arch 条件 |
| Winograd 系 | `conv_bin_wino3x3U.cpp` 等 | dtype gate（FP16/INT8 追加）、arch 条件 |
| `ConvMlirIgemmFwd` | `conv_mlir_igemm_fwd.cpp:188` | `StartsWith("gfx900") return false` の削除 |

**実例**: Tensile fallback の外部 contributor 補修（PR #1595, #1862）は、同様のロジック変更が OSS プロセスで成立した実例。

**制約**: MLIR iGEMM の gfx900 除外を変更する場合、除外の根拠が非公開 issue #389 にあるため、
技術的に変更可能でも「根拠の確認」が制約になりうる（→ `what_cannot_be_extended.md §3`）。

---

### 2. Tensile logic files および fallback 追加

**内容**: Tensile の solver 選択ロジックは Python コード（`.yaml` カタログ + `Component.py`）で記述されており、
外部 contributor が実績を持つ層。

**観測根拠（history_verified）**:

| PR | 内容 | 主体 |
|---|---|---|
| #1595 | `gfx900:xnack-` arch string 追加 | cgmb（外部 contributor） |
| #1862 | lazy loading fallback libraries 方針の実装 | GZGavinZhao（外部 contributor） |
| #1879 | #1862 の revert（Koji Nakajima, AMD 関連） | — |
| #1897 | fallback 方針の再投入 | — |

**制約**: merge / revert の経緯が示すように、AMD 側のレビューと合意が必要。OSS として変更可能だが、
upstream 採用の保証はない。source-build ユーザー向けには fork でも成立する。

---

### 3. CMake GPU_TARGETS / AMDGPU_TARGETS

**内容**: ビルド時に `AMDGPU_TARGETS=gfx900` を明示することで、
デフォルト設定から gfx900 が除外されているコンポーネントでも source-build が可能。

**観測根拠（code_verified）**:

| コンポーネント | デフォルト | 手動指定 |
|---|---|---|
| ollama CMakeLists | gfx900 を regex 除外 | `AMDGPU_TARGETS=gfx900` で再ビルド可能 |
| hipCUB | ROCm 7.0 以降デフォルト除外 | 手動追加で可能 |
| rocBLAS | デフォルト包含 | — |

**制約**: ビルドは可能だが、生成物が公式 CI でテストされるかは別問題。配布物として利用する場合、
自己でビルドと検証を引き受ける必要がある。

---

### 4. Capability テーブル

**内容**: `target_properties.cpp`（MIOpen）の device→arch マッピングはテキストベースで記述されており、
コミュニティが修正可能。

**観測根拠（code_verified）**:
- `TargetProperties::GetDeviceName()` が `gfx900` を正規化する際の sramecc workaround も同ファイルに局所化されている。
- `IsXdlopsSupport()` / `IsMlirSupportedHardware()` 等の共通 capability 関数は `implicitgemm_util.hpp` 等に集約されており、テキスト変更として完結する。

**制約**: capability テーブルの変更は、それを参照する solver 群の動作に波及する。
意図しない solver が gfx900 で試みられる状態を招く可能性があり、動作確認が必要。

---

### 5. Perf DB（チューニングデータ）の再生成

**内容**: MIOpen Perf DB は実機チューニングの結果であり、`MIOpenDriver -t` コマンドで
ユーザーが自分の環境向けに再生成できる。フォーマットは公開（SQLite / テキスト）。

**観測根拠（shipped_artifact_verified）**:
- `/opt/rocm/share/miopen/db/` の形式が公開されており、ユーザーローカルの DB に追記される仕組みが MIOpen に実装されている（`~/.config/miopen/` への書き込み）。

**制約**:
- 実機で長時間の tuning run が必要（形状ごとに秒〜分単位）
- INT8 向けには naive 以外の solver が現状通過しないため、tuning 対象が限定される
- 生成した DB を upstream に贡献するためには、MIOpen の CI パイプラインへの組み込みが必要

---

### 6. rocMLIR ソース

**内容**: rocMLIR は完全公開の OSS（`ROCm/rocMLIR`）であり、
`convGenerator.isApplicable()` 内の arch gate 条件を変更することが原理的に可能。

**観測根拠（code_verified）**:
- `mlir/tools/rocmlir-lib/rocmlir-lib.cpp` の `MiirIsConfigApplicable()` 実装を確認済み
- `convGenerator.isApplicable()` に arch 判定ロジックが存在することを確認済み

**制約**:
- rocMLIR のビルドは数時間〜日単位のコストが必要
- upstream の private issue #389 との関係が不明確であり、変更した場合の動作品質は未知

---

### 7. ASM カーネルの dtype 拡張（FP32 専用 → INT8 追加）

**内容**: `ConvAsmImplicitGemmV4R1DynamicFwd` 等の ASM カーネルは、
現在 FP32 専用設計だが、INT8 向けの積和命令列（`mul/add/mac/mad` 系）で拡張する余地が原理的にある。

**観測根拠（code_verified）**:
- gfx900 は `v_dot4_u32_u8` / `v_dot4_i32_i8` を持たないが、
  scalar/vector の加算・乗算命令で INT8 の積和を実装する代替手段は ISA 上に存在する（→ `hsaco_disassembly_notes.md`）。
- `ConvDirectNaiveConvFwd` が INT8 を通せている事実は、gfx900 の ISA が INT8 演算を原理的に禁止していないことを示す。

**制約**:
- アーキテクチャ固有の ASM 知識が必要（高難度）
- dot4 非対応でのスループットは dot4 対応世代に比べて大きく劣る
- 純粋に「動くこと」と「実用的な性能」は別問題

---

## 横断的な観測

- **コミュニティ修正の入り口は広い**: 上記7項目はいずれも公開 OSS であり、法的・技術的アクセスが存在する
- **実績がある**: Tensile fallback（PR #1595, #1862）は外部 contributor の upstream 採用実例
- **境界は「技術」より「コスト・品質保証」**: 多くの層で「原理的に変更可能」だが、「upstream に採用され持続するか」は CI・QA・レビュー合意に依存する

---

## Open Question / Limitation

1. **MLIR iGEMM の gfx900 gate 変更の技術的ハードル**: private #389 の技術的根拠が非公開のため、変更した場合の動作品質は外部から評価困難
2. **INT8 ASM カーネル拡張の性能下限**: dot4 非対応で INT8 積和を実装した場合、Naive solver との性能差はどの程度か（未評価）
3. **Perf DB の upstream 組み込み経路**: コミュニティが gfx900 向け INT8 Perf DB を生成した場合、upstream に採用される経路は現時点では不明確

---

## 本文書が主張しないこと

- 上記の変更が「実用的・持続可能なサポート」として成立すると断定するものではない
- 各変更を AMD が upstream に採用することを期待するものではない
- gfx900 の将来的なサポート継続を保証するものではない
- 特定組織や個人への評価を目的とするものではない
