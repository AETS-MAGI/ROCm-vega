# gfx900 の将来経路：現構造から読める含意

作成日: 2026-03-17
関連文書: `final_hypothesis.md §5`, `support_boundary.md`, `what_can_be_extended.md`, `what_cannot_be_extended.md`, `why_rocm_is_flexible.md`, `community_vs_vendor_matrix.md`, `provenance_map.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、将来の動向を予測するものではない。非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

`final_hypothesis.md §9`（最終的に答える問い）のうち、以下に応答する：

> 将来の再統合 / 共通化に対して、現構造は何を意味するか。

「将来の予測」ではなく、**現時点の観測された構造から読める含意** を整理する。
将来が実際どうなるかは本調査の対象外である。

---

## 1. 自然に残りやすい経路（現構造から読める）

以下は、現構造の設計上の性質から「変化が起きにくい」と読める経路と、その理由。

### 1.1 Firmware / カーネルドライバ層

**経路**: `amdgpu` KFD / DRM カーネルドライバ、vega10 firmware blob

**理由（Fact）**:
- vega10 firmware は `linux-firmware` パッケージ経由で配布されており、ROCm パッケージとは独立した配布チャネルを持つ
- Linux カーネルの `amdgpu` ドライバは GPU がアクティブである限り長期間残る傾向がある
- gfx900 は現行カーネルで `rocminfo` 認識済み（runtime_verified）

**含意**: firmware とカーネルドライバの層は、ROCm userspace の変更に関わらず比較的独立して残存しやすい。
これが「ROCm 公式サポート終了後も gfx900 が Linux 上で動く」という状態の最も安定した基盤層である。

---

### 1.2 LLVM/HIP コンパイラ backend

**経路**: LLVM の `gfx900` ISA target 定義（`GCNProcessors.td`, `SISchedule.td` 等）

**理由（Fact）**:
- gfx900 の LLVM target 定義は GCN アーキテクチャ全体の一部として存在する
- `hipcc` / `clang --offload-arch=gfx900` は現行 LLVM で動作する（runtime_verified）
- LLVM コミュニティは古いターゲットを積極的に削除する方針を基本的にとらない

**含意**: コンパイラレベルでの gfx900 サポートは、userspace library の動向に依存せず残存しやすい。
これは「source-build で gfx900 向けバイナリを生成できる」という前提条件を担保する層。

---

### 1.3 MIOpen Naive solver（ConvDirectNaiveConvFwd）

**経路**: `ConvDirectNaiveConvFwd`（常時 applicable 設計）

**理由（Fact）**:
- `IsApplicable()` は arch / dtype / layout を問わず true を返す設計
- 「最終手段」として機能するため、他 solver が全て除外された状態でも選択される
- 意図的に削除するには別の fallback solver を用意する必要があり、削除コストが高い

**含意**: Naive solver は「何も残らなくなった場合の最後の経路」として構造的に残りやすい。
ただし最適化なし設計のため、実用的な性能を前提とするユースケースでは不十分。

---

### 1.4 rocBLAS プリコンパイル済みカーネル（現配布分）

**経路**: `/opt/rocm/lib/rocblas/library/` の gfx900 向け 128 ファイル

**理由（Fact）**:
- 現行 ROCm 7.2 では出荷継続を確認済み（shipped_artifact_verified）
- `rocBLAS` の CMakeLists では gfx900 がデフォルト `TARGET_LIST` に残存している（code_verified）
- GEMM backend を必要とする上位ライブラリ（PyTorch の rocBLAS 経由 GEMM 等）への依存がある

**含意**: 出荷が継続している限り、現行パッケージユーザーには rocBLAS 経由の GEMM パスが提供される。
ただし `hipCUB` 等の除外例が示すように、将来の ROCm リリースで配布方針が変わりうる。

---

## 2. 変化が起きやすい・脆弱な層

### 2.1 コンポーネントごとのビルドターゲット管理

**経路**: 各コンポーネントの `AMDGPU_TARGETS` / `GPU_TARGETS` リスト

**理由（Fact）**:
- `hipCUB` は ROCm 7.0 でデフォルトターゲットから gfx900 を除外済み（history_verified）
- `composable_kernel` / `rocWMMA` / `rocprofiler-compute` 等は `TheRock` の `EXCLUDE_TARGET_PROJECTS` で filter 済み（code_verified）
- これらの変更は solver 除外と異なり、ビルドパイプライン側の変更のため、配布成果物が直接変わる

**含意**: 各コンポーネントが独立してターゲットリストを管理するため、
「コンポーネント単位の段階的除外」が構造上最も起きやすい変化のパターンである。

**脆弱性指標**:
- 「gfx900 が CMake ターゲットリストに残っているコンポーネント」が減ることで、
  依存コンポーネントが連鎖的に動かなくなるリスクがある
- 特に「source-build では動く」状態が長く続くと、公式配布物との乖離が広がる

---

### 2.2 MIOpen Perf DB の更新停止

**経路**: `/opt/rocm/share/miopen/db/` の gfx900 向け tuning データ

**理由（Fact）**:
- 現行 ROCm 7.2 では出荷継続を確認済み（shipped_artifact_verified, 169K行）
- Perf DB が「そのまま引き継がれているか」「ROCm リリースごとに再生成されているか」は未確認（Open Question）
- チューニングデータの鮮度が下がると、実際の性能と Perf DB の乖離が広がる可能性がある

**含意**: Perf DB が「いつ最後に更新されたか」は本調査では未確認。
もし過去のスナップショットがそのまま引き継がれているなら、
新しい ROCm バージョンに合わせた再チューニングは既に停止している可能性がある。

---

### 2.3 Tensile fallback 経路の保守継続

**経路**: Tensile lazy loading fallback（PR #1862 → #1897 系）

**理由（Fact）**:
- 現状の fallback 経路は外部 contributor によって投入・維持されている（history_verified）
- `#1862` が AMD 関連の `#1879` で revert された経緯がある
- AMD 側が fallback 方針を変更した場合、外部 contributor の変更が再 revert されるリスクがある

**含意**: Tensile fallback は「コミュニティが延命している層」の典型だが、
AMD の方針変更によって失われる可能性がある。外部 contributor の補修が積み上がっても、
上流の merge / revert 権限は AMD 側にある。

---

## 3. TheRock 移行との接続

**観測（code_verified）**:

```cmake
# therock_amdgpu_targets.cmake
therock_add_amdgpu_target(gfx900 ...)  # global target として登録

# therock_subproject.cmake
EXCLUDE_TARGET_PROJECTS
  hipBLASLt hipSPARSELt composable_kernel rocWMMA rocprofiler-compute
  ...
```

**Fact**:
- `TheRock` への移行後も gfx900 は `global target` として登録されたまま
- ただし `hipBLASLt` / `hipSPARSELt` / `composable_kernel` / `rocWMMA` / `rocprofiler-compute` は除外
- この構造は「一括削除」ではなく「project ごとの selective exclude」として読める

**含意**:

1. TheRock 移行後も「gfx900 のターゲット登録 + 一部 project からの除外」という構造は引き継がれる可能性がある
2. monorepo 化による変化の一つは「除外の明示化」: 現在は各コンポーネントに散在していた除外条件が `EXCLUDE_TARGET_PROJECTS` に集約される
3. 集約されることで、「gfx900 を再追加する」際のコストが変わる可能性がある（一箇所で管理 → 変更が局所化）

**留保**: TheRock 移行の completion 状況は現在進行形であり、
この分析は current `TheRock` repo（2026-03-17 時点）への観測に基づく。

---

## 4. 再統合・共通化への構造的含意

`final_hypothesis.md §5` で示した「Layered Retreat が起きやすい構造」は、
逆から見ると「layer ごとの再統合が技術的に可能な構造」でもある。

### 4.1 再統合が技術的に成立しやすい層

| 層 | 再統合の形 | 成立条件 |
|---|---|---|
| solver `IsApplicable()` | gfx900 の gate 条件を緩和・削除 | コード変更 + テスト |
| CMake `AMDGPU_TARGETS` | リストに gfx900 を再追加 | ビルド設定変更 |
| Tensile fallback | 外部 contributor PR の継続的投入 | upstream merge 合意 |
| Perf DB | gfx900 向け再チューニング | 実機 + 時間 + upstream 組み込み |

### 4.2 再統合が技術的に困難な層

| 層 | 理由 |
|---|---|
| MLIR iGEMM gfx900 対応 | private #389 の技術的根拠が非公開 |
| INT8 最適化（dot4 依存部） | 物理制約（dot4 不在）。代替実装は性能限界がある |
| 公式 QA / CI 組み込み | 組織的境界 |
| XDLops / MFMA 系 solver | 物理制約（MFMA 不在）。恒久的 |

### 4.3 「再統合」と「共通化」の違い

- **再統合**: gfx900 が既存の最適化経路で動く状態への復帰
  - 多くの経路で技術的には可能だが、性能・品質・持続可能性の評価が必要
- **共通化**: gfx900 を含む世代横断的な抽象レイヤの強化
  - capability-based 設計は既にこの方向に向いている（`why_rocm_is_flexible.md §2`）
  - LLVM target 定義・HIP runtime の共通基盤は既に横断的に機能している

---

## 5. Interpretation

- gfx900 の「将来経路」は、単一のイベント（サポート終了宣言・明示的削除）によって変わるよりも、
  **component ごとの段階的変化の積み重ね** によって変わる構造になっている
- 「自然に残りやすい層」（firmware / LLVM / Naive solver）と「段階的に失われやすい層」（各 component の ターゲットリスト / Perf DB 更新）が混在しており、両者は独立して動きうる
- コミュニティの介入が最も効きやすい層は、**Tensile logic / CMake targets / MIOpen solver 条件** であり、これらはすでに外部 contributor の実績がある
- 再統合の技術的ハードルは「物理制約」「非公開制約」「組織的制約」の3種に分類でき、
  それぞれ対応策の性質が異なる

---

## Open Question / Limitation

1. **MIOpen Perf DB の更新タイミング**: 現在出荷されているデータがいつ最後に再チューニングされたかは未確認。「出荷されている」と「最新の状態に保たれている」は別問題
2. **rocBLAS fallback ファイルの将来**: `fallback` 名を含む 54/128 ファイルが gfx900 向けに存在するが、これが将来のリリースで引き続き生成・出荷されるかは未確認
3. **TheRock 移行の最終形**: monorepo 移行が完了した段階での gfx900 の扱いは、現在進行中のため未確定
4. **コミュニティ補修の持続可能性**: Tensile fallback の外部 contributor が将来も活動を継続するかは不明。人的依存性の高い経路は脆弱になりうる

---

## 本文書が主張しないこと

- gfx900 の将来の動作を保証・予測するものではない
- AMD の将来の方針を断定するものではない
- 「再統合が行われるべき」という規範的主張を含まない
- コミュニティによる補修の成功を保証するものではない
- 特定組織や個人への評価を目的とするものではない
