# ROCm support model hypothesis

作成日: 2026-03-18
関連文書: `design_philosophy.md`, `abstraction_layers.md`, `support_boundary.md`, `final_hypothesis.md`, `why_rocm_is_flexible.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 一次根拠

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/ROCm/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/ROCm/docs/what-is-rocm.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/cmake/therock_amdgpu_targets.cmake`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/cmake/therock_subproject.cmake`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/projects/hip/docs/how-to/hip_runtime_api.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/projects/hip/docs/understand/programming_model.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocBLAS/docs/what-is-rocblas.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/doc/src/find_and_immediate.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_public-archive/LLVM-AMDGPU-Assembler-Extra/README.md`

---

## 目的

思想層で残っていた問いを、`gfx900` 調査に直接使える形で閉じる。

主に答えたいのは次の 4 点である。

1. ROCm 各コンポーネントの責務は何か
2. ROCm の support はどの層で成立し、どの層で後退するのか
3. fallback や backend 切替は場当たり対応か、構造の一部か
4. repo migration / archive を support の意味とどう切り分けるか

---

## 1. コンポーネント責務の最小表（Fact）

| コンポーネント | 一文での主責務 | 主に担う性格 |
|---|---|---|
| `ROCR-Runtime` | HSA runtime として lower runtime backend を提供する | 抽象化 / 実行基盤 |
| `HIP` | host-facing な GPU runtime API を提供し lower backend を隠蔽する | 抽象化 / 互換性 |
| `MIOpen` | DNN library API の背後で solver 選択・tuning・kernel 実行を管理する | 最適化 / 互換性 |
| `rocBLAS` | BLAS API を thin surface として提供し GEMM を下位 backend に委譲する | 抽象化 / 最適化 |
| `Tensile` | GEMM solution catalog と codegen / fallback を担う | 最適化 |
| `CK` | architecture-aware な kernel template / specialized implementation を提供する | 最適化 |
| `TheRock` | multi-component source build の integration policy を統合する | 統合 / 管理 |
| `rocm-systems` | systems-side repo の source-of-truth と CI/integration を集約する | 統合 / 管理 |

少なくとも public docs / code からは、
ROCm の各部品は「全部が同じ意味で support を担う」のではなく、
**抽象化 / 最適化 / 互換性 / 統合管理** を分担していると読める。

---

## 2. support を読むための層（Fact）

### 2.1 support plane table

| support plane | 何を見るか | 代表的な観測点 |
|---|---|---|
| 表の support | 公式推奨、QA、release note、default build | release note, CI, package defaults |
| build / integration support | target が global に定義され build policy に残るか | `TheRock` target metadata, repo migration |
| design / capability support | capability 判定と fallback が target を通しうるか | `IsApplicable`, `IsXdlopsSupport`, backend selection |
| distribution support | 実成果物が package に載るか | Perf DB, rocBLAS code object, firmware |
| practical / community support | source-build や local patch により運用できるか | source build, external contributor patch, workaround |

### 2.2 gfx900 への当てはめ

| plane | gfx900 の観測 |
|---|---|
| 表の support | 新しい mainline path では後退が見える |
| build / integration support | global target としては残るが component ごとに selective exclude がある |
| design / capability support | legacy solver / fallback では残り、新しい MLIR / XDLops 系では後退する |
| distribution support | Perf DB / rocBLAS / firmware の残存が確認できる |
| practical / community support | source-build と一部 external contribution により実用余地が残る |

Interpretation:
`gfx900` は「supported / unsupported」の単一値ではなく、
**plane ごとに強さが異なる target**
として読んだ方が整合的である。

---

## 3. capability-based support と local gate（Interpretation）

### 3.1 capability-based core

既存調査で確認したとおり、

- `MIOpen` は solver 全件列挙 + `IsApplicable()`
- `rocBLAS` は thin API + lower backend 委譲
- `TheRock` は global target + per-project exclusion

という形をとる。

このため、support の中心は
**「この target を一括で許可 / 禁止する」より、
capability と component-local gate の組み合わせ**
として表現されやすい。

### 3.2 local exception は残る

ただし support が完全に capability-based だけで決まるわけではない。

例:

- MIOpen MLIR iGEMM の `gfx900` 明示除外
- `TheRock` の `EXCLUDE_TARGET_PROJECTS`
- component ごとの default build 後退

Interpretation:
ROCm は、
**capability-based core の上に local policy / local gate が重なる構造**
と読むのが最も無理が少ない。

---

## 4. 「速い経路」と「広く通る経路」は分離されている（Interpretation）

`gfx900` 調査で一貫して見えているのは、
新しい optimized path が先に後退し、
広く通る経路や legacy path が後に残る、という非対称性である。

| 経路の型 | 典型例 | gfx900 での観測 |
|---|---|---|
| 新しい optimized path | MLIR iGEMM, XDLops, CK iGEMM | 後退 / 不成立が多い |
| 広く通る path | ASM v4r1, Winograd, naive, Tensile fallback | 残存が観測される |

Interpretation:
これは場当たり対応より、
**fast path と broad path が構造的に分離されている**
と読む方が自然である。

---

## 5. backend 切替と fallback は構造の一部である（Interpretation）

### 5.1 backend switching

public docs / code からは次が見える。

- `HIP` runtime は lower backend を隠蔽する
- `rocBLAS` は Tensile / hipBLASLt に委譲する
- `MIOpen` は `Find / GetSolution / CompileSolution / Immediate` を通して backend realization を遅延させる

### 5.2 fallback

既存調査で観測された fallback は、少なくとも複数 component にまたがる。

- MIOpen の legacy solver / naive path
- rocBLAS / Tensile 側の fallback libraries
- `TheRock` における selective exclude と buildable target の分離

Interpretation:
fallback は one-off patch ではなく、
**ROCm の複数層で再出現する設計パターン**
として扱う方が整合的である。

---

## 6. repo migration / archive をどう読むか（Fact + Interpretation）

### 6.1 current / migrated / archived roots

| root | 役割 | support 読みへの含意 |
|---|---|---|
| `ROCm`, `TheRock`, `rocm-systems` | current integration / source-of-truth roots | build / integration policy を読む主要根拠 |
| `00_legacy-repos` | retired / legacy implementation roots | 過去の投入主体と後退点を読む主要根拠 |
| `00_public-archive` | public archive 化された補助 repo 群 | repo topology の履歴を読む補助根拠 |

### 6.2 LLVM-AMDGPU-Assembler-Extra が示すこと

`LLVM-AMDGPU-Assembler-Extra` の README では、
2016 年時点で

- LLVM trunk build
- latest ROCR runtime
- AMDGPU ISA assembler helper tools

を別 repo の helper tool 群として扱っていることが確認できる。

Interpretation:
少なくとも ROCm / LLVM 周辺では、
**LLVM-adjacent tooling が standalone repo として置かれ、後に archive 化されうる**
という repo topology の変遷が public に観測される。

ここから直ちに言えるのは次までである。

- repo の source-of-truth や居場所は変わりうる
- archive 化は topology / maintenance location の変化を示す

ここから直ちには言えない。

- archive された repo に関係する target support が同時に消えた
- 特定 arch の support policy が archive だけで決まる

つまり、repo migration / archive は
**support policy の直接証拠というより、保守構造の補助証拠**
として読むのが安全である。

---

## 7. working hypothesis

以上を踏まえると、現時点の working hypothesis は次である。

1. ROCm の support は binary property ではなく multi-plane property である
2. target の後退は、global target 削除より前に component-local gate と optimized path 側で先に起きやすい
3. fallback と backend switching は場当たり対応ではなく recurring design pattern として観測される
4. repo migration / archive は support の直接証拠ではなく、source-of-truth と maintenance location の変化を示す補助証拠である

`gfx900` はこの model に最もよく合う観測点であり、
だからこそ「半分死んで半分生きている」ように見える。

---

## Open Question / Limitation

- `TheRock` と `rocm-systems` が今後どこまで math / ML library 側を吸収するかは未確定
- `00_public-archive` は repo topology の補助根拠として有用だが、各 archive repo が個別 target support にどう影響したかは別途精査が必要
- `rocm-libraries` の local worktree は引き続き一次根拠に使いにくい

---

## 本文書が主張しないこと

- AMD の社内 support policy 全体を完全に再構成するものではない
- repo archive の事実だけから target support の終了を断定するものではない
- private issue の内容を推定で補完するものではない
- 単一事例から ROCm 全体の不変法則を断定するものではない
- 特定組織や個人への批判を目的とするものではない
