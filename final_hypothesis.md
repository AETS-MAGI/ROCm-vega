# 最終仮説整理：Vega/gfx900 はなぜ今も生きているか

作成日: 2026-03-17
関連文書: `hypothesis.md`, `facts.md`, `class_map.md`, `support_boundary.md`, `provenance_map.md`, `trace_map_static.md`, `trace_map_dynamic.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 中心的な問い

> Vega/gfx900 はなぜ今も生きているのか。
> 情けで放置されているのか、設計上自然に残っているのか。
> 「サポート終了」とは何を意味するのか。
> コミュニティはどこまで実質サポートを成立させられるか。

---

## 1. 観測の要約（Fact）

以下は、公開コード・git 履歴・実機ログから確認済みの事実である。

### 1.1 生存する実行経路（code_verified / runtime_verified）

| 経路 | 種別 | 確認方法 |
|---|---|---|
| `ConvAsmImplicitGemmV4R1Dynamic{Fwd,Bwd,Wrw}` | gfx900/gfx906 専用 ASM solver | `IsApplicable()` ソース確認 + 実機 FP32 自然選択 |
| `ConvBinWinograd3x3U` / `ConvBinWinoRxS` | Winograd binary solver（FP32） | ソース確認 + 実機選択 |
| Tensile lazy loading fallback（gfx900） | `TensileLibrary_lazy_gfx900.yaml` 相当の設計 | `tensile_host.cpp` ソース確認 |
| rocBLAS プリコンパイル済みカーネル 128 個 | 出荷済み成果物 | `/opt/rocm/lib/rocblas/library/` 実測 |
| MIOpen Perf DB: gfx900_56/64 向け 169,182 行 | 出荷済みチューニングデータ | Perf DB 行数実測 |
| vega10 firmware 16 ファイル | 出荷済み firmware blob | `/lib/firmware/amdgpu/` 実測 |

### 1.2 除外される実行経路（code_verified / runtime_verified）

| 経路 | 除外条件 | 確認方法 |
|---|---|---|
| `ConvMlirIgemm{Fwd,Bwd,Wrw}` | `IsApplicable()` 内の `StartsWith("gfx900") → return false` | ソース確認 + 強制実行で `boost::optional` crash を実機確認 |
| XDLops 系 solver（`ConvHipImplicitGemmFwdXdlops` 等） | `IsXdlopsSupport() → false`（gfx908 未満） | ソース確認 + 強制実行で assertion abort |
| CK iGEMM 系（`ConvCkIgemmFwdV6r1DlopsNchw` 等） | `IsApplicable()` で全件 `not applicable` | 強制実行 15+ ケース全件 `rc=0x3` |

### 1.3 MLIR iGEMM 除外の provenance（history_verified）

- 除外コミット: `2407d2f`（2021-12-22）、作者: Zhuoran Yin（AMD 社員）
- コミットメッセージ: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
- 参照先: `llvm-project-private/issues/389`

> この issue は非公開であり、本文は外部から確認できない。したがって、ここから言えるのは、公開コード側に参照関係と gating の痕跡が存在するという範囲に限られる。

- PR #1328 の公開本文からは「ROCm 5.1 向け MLIR solver チューニングに先立つ調整 PR」であることが読める。
- ctest の gfx900 無効化を含む計画的な変更であり、単行の削除ではない（`history_verified`）。

### 1.4 二重構造（code_verified）

`IsMlirSupportedHardware()`（`mlir_common.hpp`）は gfx900 を「MLIR 対応ハード」として列挙する一方、
`ConvMlirIgemmFwd::IsApplicable()` は後段で gfx900 を明示除外する。
この二重構造が「MLIR 対応ハードのはずなのに MLIR iGEMM が使えない」という見かけ上の矛盾を生んでいる（→ `class_map.md §gfx900 に対するフィルタ位置` 参照）。

### 1.5 保守主体の分布（history_verified）

| 経路 | 投入主体 | 最終保守実績 |
|---|---|---|
| ASM v4r1 dynamic | AMD contributor（carlushuang, 2020） | Bug fix: shaojiewang, 2021 |
| Winograd binary | 初期 MIOpen 時代 | Perf workaround: Slimakanzer, 2023 |
| MLIR iGEMM 除外 | AMD 社員（jerryyin, 2021） | URL 修正のみ: Artem Tamazov, 2023 |
| Tensile gfx900:xnack- 追加 | 外部 contributor（cgmb, 2022） | — |
| Tensile lazy loading fallback | 外部 contributor（GZGavinZhao, 2024） | — |

---

## 2. 解釈（Interpretation）

以下は、上記の観測から読める解釈である。断定ではなく、観測と整合する仮説として提示する。

### 2.1 仮説 A: 「サポート終了」と「実行経路の消滅」は別の現象として観測される

「公式サポート終了」は、少なくとも観測可能な範囲では、次の4層で異なるタイミング・深度で進んでいることが確認される。

| 層 | 定義 | gfx900 の現状（観測ベース） |
|---|---|---|
| **表のサポート** | 公式推奨・QA 対象・優先修正 | 弱い（ROCm リリースノートから後退） |
| **設計上のサポート** | capability 判定・fallback 経路の存在 | 残存している（ソース確認済み） |
| **配布上のサポート** | プリコンパイル済み成果物・Perf DB の出荷 | 残存（gfx1100/1200 より大きい層も観測） |
| **運用上のサポート** | Bug 報告受付・CI 通過可否 | 確認中 / 保証外と読める |

この観測から、「サポート終了」という語が指す層は、発言主体や文脈によって異なることが示唆される。

### 2.2 仮説 B: gfx900 の生存は、capability-based 設計の自然な帰結として読める

MIOpen の solver finder は「全候補列挙 → `IsApplicable()` フィルタ」方式をとる（→ `class_map.md` 参照）。
このフィルタは arch を capability として扱う汎用設計であり、gfx900 専用コードではない。

結果として、「gfx900 で成立できる solver」が自然に残り、「gfx900 では成立しない solver」が自然に落ちる。
少なくとも構造上は、gfx900 向けの生存経路は「例外的な配慮」ではなく「capability-based 設計の副産物」として説明できる。

同様に、CK の dot4 非対応フォールバック（逐次積和）や、Tensile の HIP source fallback も、
gfx900 専用実装ではなく「capability 非対応時の汎用フォールバック」として設計されている。

### 2.3 仮説 C: 保守主体は層によって異なることが観測される

- ASM v4r1 dynamic・Winograd など初期 ROCm 時代の solver は、現時点では AMD による積極的な機能追加は観測されず、「残置」と読めるが、2021〜2023 年には Bug fix・Perf workaround が投入されている。
- Tensile の gfx900 fallback は外部 contributor による補修として観測され、「コミュニティによる延命」と読める。
- MLIR iGEMM の gfx900 除外は AMD 社員による計画的な変更として観測され、その根拠は非公開 issue に閉じている。

主体を単線化して「AMD が切った」「コミュニティが支えている」とは言えない。層ごとに投入主体・維持主体・修正可能主体が異なる。

### 2.4 仮説 D: RDNA/CDNA 分岐前の GCN アーキテクチャは、現行スタックの共通の先行世代として構造的に残りやすい

gfx900（Vega10、GCN5）は、RDNA（gfx10xx）・CDNA（gfx908/90a）双方の先行世代にあたる。
RDNA/CDNA で分離した機能（xdlops / MFMA / dot4 等）が gfx900 にない一方、共通の基盤層（LLVM target 定義・ISA 基本命令・HIP runtime）は引き続き gfx900 をカバーしている。
この構造が、「最新機能は使えないが基本動作は通る」という状態を維持する一因として観測される。

### 2.5 仮説 E: 変化は「一括削除」ではなく「component ごとの時間差後退（Layered Retreat）」として観測される

- `ROCm 7.0.0` の `hipCUB (4.0.0)` で gfx900 が default build から後退
- `ROCm 5.1` の MLIR iGEMM で gfx900 が除外
- `ROCm 5.5.0` の Tensile では gfx900:xnack- が追加（外部 contributor）
- rocBLAS / MIOpen Perf DB / firmware は出荷継続（2026-03-17 時点）

MIOpen の `IsApplicable()` フィルタが solver 単位・dtype 単位で独立しているため、
「ある solver だけ除外・別 solver は残存」という粒度の後退が構造的に成立しやすい。
これは意図されたものかは観測できないが、少なくとも結果として Layered Retreat として読める。

---

## 3. 未解決事項（Open Question / Limitation）

### 3.1 private issue #389 の技術的根拠

`llvm-project-private/issues/389` の本文は外部から確認できない。
公開情報から読めるのは「MLIR コンパイラバックエンド（AMDGPU codegen）レベルの制約を示唆する参照先である」という範囲に限られる。
`Disable` という語のニュアンス（一時的停止か恒久除外か）も現時点では断定できない。

### 3.2 INT8 非 naive solver の自然選択未達

gfx900 での INT8 convolution について、`ConvDirectNaiveConvFwd` 以外の solver が自然選択されるケースは
探索した全件（15+ ケース）で未確認。「非 naive が選ばれない」という結論は `runtime_verified` だが、
すべての入力形状・layout・精度条件を網羅したわけではない。

### 3.3 運用上のサポート（バグ報告・CI）の現状

gfx900 関連 bug が現行 CI で検出可能か、bug 報告が受理されるかは本調査の範囲外。
「設計上の生存」と「運用上の保証」は別問題であり、後者は確認できていない。

### 3.4 出荷成果物比較の前提条件

§1.1 で挙げた Perf DB 行数比較（gfx900: 169K行 / gfx1100: 0行 / gfx1200: 0行）は、
**「同じチューニングメカニズムを前提とした場合のみ公平な比較になる」** という留保が必要である。

MIOpen は `MIOPEN_ENABLE_AI_IMMED_MODE_FALLBACK` / `MIOPEN_ENABLE_AI_KERNEL_TUNING` 等の
AI-based チューニング機能を持つ。RDNA3/4（gfx1100/1200）がこれらの機能や CK-based tuning を
主要経路として採用している場合、従来の Find-DB 方式の Perf DB 行数が少ない（または存在しない）ことは
「チューニングデータが薄い」ではなく「別のメカニズムを使っている」という解釈になりうる。

現時点では次の点が未確認である：

- gfx1100/1200 で実際に採用されている MIOpen solver のチューニング方式
- AI-based tuning が gfx900 に対してどの程度有効か（本調査のデバッグビルドは AI 機能 Off で構成）

**この留保が解消されない限り、出荷成果物比較を「gfx900 の方が gfx1100/1200 より手厚い」という主張の直接根拠として使うことは過剰である。**
より正確には「gfx900 向けに Find-DB 形式の大規模チューニングデータが出荷されている」という事実の記述にとどめ、世代間比較は参考値として扱うのが適切である。

### 3.5 TheRock への移行後の変化

`TheRock` への monorepo 移行（`ROCm/rocm-libraries`, `ROCm/rocm-systems` 等）が
gfx900 の取り扱いにどう影響するかは、現時点では一次資料が不十分で断定できない。
`TheRock/cmake/therock_amdgpu_targets.cmake` には target list が存在するが、
gfx900 の扱いを最終確認するには別途調査が必要。

---

## 4. 問いへの回答（現時点の観測ベース）

### Q1: gfx900 はなぜ今も生きているのか

「情けで放置」でも「意図的な維持」でもなく、少なくとも構造上は次の説明が観測と整合する：

1. capability-based な設計が、gfx900 で成立する solver を自然に残している（仮説 B）
2. 初期 ROCm 時代に投入された solver が積極的に削除されていない（残置）
3. 一部はコミュニティ contributor が fallback 経路を補修している（仮説 C）
4. 出荷成果物（Perf DB / rocBLAS / firmware）のビルドパイプラインに gfx900 が残っている（配布層）

これらが重なって「動く状態」が維持されていると読める。

### Q2: 「サポート終了」とは何を意味するのか

観測できる範囲では、「ROCm 公式サポート終了」は少なくとも次を意味する：

- **意味する**: QA 対象外、公式推奨リスト外、優先修正対象外
- **直ちには意味しない**: 実行経路の即時消滅、出荷成果物からの即時除外、LLVM target 定義の削除

「サポート終了」という語は、層によって異なる現象を指している可能性が観測から示唆される。

### Q3: コミュニティはどこまで実質サポートを成立させられるか

`support_boundary.md` の分析と合わせると、現時点では次のように読める：

| 層 | コミュニティ修正可能性 |
|---|---|
| MIOpen solver ソース（IsApplicable 条件等） | 原理的に可能（公開 OSS） |
| Tensile logic files / fallback | 実績あり（外部 contributor による補修）  |
| rocMLIR（Miir 実装） | 原理的に可能（公開 OSS） |
| MLIR/LLVM コンパイラバックエンド | 可能だが難度が高い（大規模 OSS） |
| MLIR iGEMM の gfx900 再対応 | private issue の根拠が非公開のため、障壁の実態が不明確 |
| firmware / kernel-mode driver | コミュニティ単独では困難 |
| QA 保証・リリース判定 | コミュニティ単独では成立しない |

「コミュニティが触れる層」は広いが、「実質サポートとして成立する」かどうかは
品質保証・CI・ドライバ層の整備を含む別の条件に依存する。

---

## 5. 構造的含意

以下は、上記の観測と解釈から読める構造的な含意である。
将来の動向についての予測ではなく、現時点の構造から示唆されることを記述する。

### 5.1 「層単位の後退」は構造上起きやすい

solver が `IsApplicable()` フィルタで独立していること、component ごとに CMake target list が分離していることから、
「特定 solver だけを除外」「特定 component だけ target から外す」という粒度の後退が構造的に成立しやすい。
これは「一括削除」より保守的な変化のペースをもたらすと読める。

### 5.2 コミュニティ修正の入り口は存在する

Tensile の外部 contributor 事例（PR #1595, #1862）は、
「AMD が公式にメンテしない経路でも、OSS の仕組みで補修が入る」という実例として観測される。
ただしこれが「再現可能・持続可能なサポート」かどうかは、CI・QA の有無に依存し、現時点では確認できていない。

### 5.3 MLIR iGEMM の gfx900 除外は、他の除外と性質が異なる

他の除外（XDLops 系・CK 系）は「gfx900 に存在しない命令セットへの依存」として構造上自然な除外として読めるが、
MLIR iGEMM の除外は `IsMlirSupportedHardware()` が gfx900 を含んだまま後段で個別除外する形をとっており、
「構造上自然な除外」とは異なる性質に見える。
根拠は非公開 issue に閉じており、この差異の技術的理由を公開情報だけで確定することはできない。

---

## 本文書が主張しないこと

- 社内意思決定過程を断定するものではない
- 非公開 issue（`llvm-project-private/issues/389`）の本文を推定で補完するものではない
- 単一事例から ROCm 全体の support policy を断定するものではない
- AMD または特定個人・組織の設計判断を評価・批判するものではない
- 将来の gfx900 サポート状況を予測するものではない

---

## 参照文書

| 文書 | 参照内容 |
|---|---|
| `class_map.md` | MIOpen クラス責務・フィルタ位置・接続点 |
| `trace_map_static.md` | solver 登録 → IsApplicable → MLIR 境界の静的結線 |
| `trace_map_dynamic.md` | 動的失敗シグネチャ対応表 |
| `support_boundary.md` | 4層モデル・コミュニティ修正可能性の境界 |
| `provenance_map.md` | 各経路の導入・維持主体マップ |
| `facts.md` | 確定した事実（code/runtime_verified 分類） |
| `hypothesis.md` | 仮説 A〜E の詳細・根拠・検証進捗 |
| `solver_observation_log.md` | 実機 solver 選択ログ集積 |
