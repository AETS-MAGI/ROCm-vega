# gfx900 の自然維持シナリオ

作成日: 2026-03-17
関連文書: `final_hypothesis.md`, `future_support_paths.md`, `support_boundary.md`, `why_rocm_is_flexible.md`, `community_vs_vendor_matrix.md`, `provenance_map.md`, `abstraction_layers.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、将来の動向を予測するものではない。非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

`future_support_paths.md` が「現構造から読める将来の含意」を整理するのに対し、
本メモは **gfx900 がどの条件で自然に維持されやすいか / どの条件で維持が崩れやすいか**
を、層と主体に分けて整理する。

中心的な問いは次の4つである。

- 現状の設計で自然に残る層はどこか
- 消えるならどの層から消えやすいか
- 再統合の観点から重要な接点はどこか
- コミュニティが押さえるべき層はどこか

---

## 1. 観測アンカー（Fact）

以下は、シナリオ整理の前提として置く観測点である。

1. `TheRock` では `gfx900` 自体は global target として登録される一方、
   `EXCLUDE_TARGET_PROJECTS` により `hipBLASLt` / `hipSPARSELt` / `composable_kernel` /
   `rocWMMA` / `rocprofiler-compute` が個別に除外される。
2. `MIOpen` の `ConvMlirIgemmFwd::IsApplicable()` は `StartsWith(device_name, "gfx900")`
   で後段除外する。
3. gfx900 では、FP32 の ASM / Winograd、rocBLAS 出荷成果物、MIOpen Perf DB が残存している。
4. INT8 では、自然選択された非 naive solver は未観測であり、`ConvDirectNaiveConvFwd` が最後の受け皿として機能している。
5. Tensile fallback 系には外部 contributor による補修実績がある。

---

## 2. 自然維持シナリオ

| シナリオ | 維持の主因 | 残りやすい層 | 先に崩れやすい層 | 主な主体 | gfx900 への実務的影響 |
|---|---|---|---|---|---|
| **S1: 受け皿残存型** | capability-based 判定と fallback の分離 | Naive solver、汎用 fallback、LLVM/HIP の共通基盤 | 高性能 solver、dtype/arch 特化 path | AMD(M) が作った共通設計 + 一部 ExtC | 「遅いが動く」が長く残りやすい |
| **S2: 配布残置型** | build / packaging が過去成果物を持ち続ける | rocBLAS 成果物、MIOpen Perf DB、firmware | 最新 QA、更新頻度、世代横断の公平性 | AMD(M) / packaging | source-build しなくても当面は動く可能性がある |
| **S3: 選択的後退型** | project ごとの target filter / solver gate | global target、共通 runtime | 個別 project、個別 solver family | AMD(M) 主導 | 「全部消える」のではなく、部分的に使えなくなる |
| **S4: コミュニティ補修型** | OSS 上の局所パッチ投入 | Tensile fallback、CMake target、solver 条件 | QA、release 判定、driver / firmware | ExtC + upstream reviewer | 配布より source-build 側で延命しやすい |
| **S5: 硬い境界型** | 物理制約 / private 根拠 / 組織境界 | 共通インフラのみ | MFMA/XDLops、private 根拠付き MLIR gate、公式 QA | 物理制約 + AMD(M) | 「動くようにする」より「別経路で回す」設計になる |

---

## 3. シナリオごとの読み

### 3.1 S1: 受け皿残存型

`why_rocm_is_flexible.md` で整理したように、
ROCm / MIOpen は「登録」と「適用判定」と「backend / artifact」を分離している。
このため、最適化経路が消えても、最後の受け皿である fallback が残りやすい。

gfx900 では INT8 の自然選択が `ConvDirectNaiveConvFwd` に集中しており、
このシナリオがすでに観測されている。

### 3.2 S2: 配布残置型

`support_boundary.md` と `facts.md` で確認した通り、
gfx900 向けの rocBLAS 成果物、MIOpen Perf DB、firmware は出荷物として残っている。
これは「いまも動く」根拠として強いが、同時に
「どこまで再生成され続けているか」は別問題である。

したがって、このシナリオは
**短中期の実用性は支えるが、長期の更新保証までは含まない**
と読むのが安全である。

### 3.3 S3: 選択的後退型

`TheRock` の `EXCLUDE_TARGET_PROJECTS` や
`ConvMlirIgemmFwd::IsApplicable()` の `gfx900` gate が示すのは、
gfx900 が monolithic に消えるのではなく、
project / solver family ごとに個別後退しうる構造である。

このシナリオでは、ユーザー視点では
「ROCm は入るが、一部 library / solver だけが使えない」
という形で現れやすい。

### 3.4 S4: コミュニティ補修型

`community_vs_vendor_matrix.md` と `provenance_map.md` が示す通り、
gfx900 の残存経路には外部 contributor の補修実績がある。
特に Tensile fallback は、AMD maintainer だけではなく
OSS contributor の介入余地が現実に存在した層である。

ただし、このシナリオで維持されやすいのは
**公開コードで局所修正できる範囲** に限られる。
release 判定、CI、QA、firmware 配布はこのシナリオの外にある。

### 3.5 S5: 硬い境界型

XDLops / MFMA 系のように物理制約で成立しない経路、
あるいは MLIR iGEMM のように private issue 参照付きの gate がある経路は、
自然維持シナリオの外側にある。

ここでは「元に戻す」よりも、
別の fallback や別の solver family へ逃がす方が現実的である。

---

## 4. コミュニティが押さえるべき接点

| 接点 | なぜ重要か | 期待できること | 限界 |
|---|---|---|---|
| `TheRock` の target / exclude 設定 | 配布対象の入口だから | target の再追加、除外理由の可視化 | release policy 自体は別問題 |
| MIOpen の `IsApplicable()` 条件 | solver 到達可否を直接決めるから | 特定 solver family の gate 緩和 | private 根拠・品質保証は残る |
| Tensile fallback / catalog 生成 | GEMM backend の実用性に直結するから | fallback 維持、logic 拡張 | upstream merge / revert に依存 |
| Perf DB / tuning 生成工程 | 実用性能に直結するから | 再チューニング、更新有無の可視化 | 実機・時間・組み込みコストが大きい |
| shipped artifacts の実測監視 | 「コードがある」と「配布される」を分けられるから | 後退の早期検知 | 維持そのものは保証しない |

---

## 5. Interpretation

- gfx900 の維持は、単一の「サポート継続」ではなく、`S1-S5` の複数シナリオが同時に重なって成立していると読める。
- 自然に残りやすいのは、共通基盤・最後の受け皿・過去の出荷成果物である。
- 先に崩れやすいのは、個別 solver、個別 project、最新 QA に依存する層である。
- コミュニティが実際に効きやすいのは、公開コードで局所変更できる接点であり、配布・QA・driver 層ではない。
- したがって、gfx900 の「自然維持」は、
  **高性能経路まで含めた完全維持** ではなく、
  **共通基盤と fallback を軸にした不均一な維持** として読むのが最も整合的である。

---

## Open Question / Limitation

1. `MIOpen` Perf DB が現在も定期的に再生成されているかは未確認
2. `TheRock` の target / exclude 設定が今後の release packaging にどう反映されるかは未確定
3. コミュニティ補修が長期的に維持されるかは、個別 contributor と upstream review に依存する
4. MLIR iGEMM gate の技術的根拠は private issue に閉じており、外部からは境界しか確認できない

---

## 本文書が主張しないこと

- gfx900 の将来の維持を保証するものではない
- AMD の将来方針を断定するものではない
- コミュニティ補修が必ず成功すると主張するものではない
- 特定組織や個人への批判を目的とするものではない
