# gfx900 調査の既知事項と未確定事項

作成日: 2026-03-17
関連文書: `facts.md`, `final_hypothesis.md`, `vega-rocm.md`, `support_boundary.md`, `gfx900_int8_path_inventory.md`, `provenance_map.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

調査全体で繰り返し参照される論点について、

- **何が既知か**
- **何が未確定か**
- **どこまでなら言えるか**

を 1 ページで固定する。

本文は「再説明」ではなく **canonical な確認表** として使う。

---

## 1. 既知事項（Knowns）

| 論点 | 既知事項 | 確度 | 主な参照先 |
|---|---|---|---|
| MLIR iGEMM の gfx900 | `ConvMlirIgemm*::IsApplicable()` は `gfx900` を明示除外する | code_verified / history_verified | `facts.md`, `vega-rocm.md`, `final_hypothesis.md` |
| MLIR 二重構造 | `IsMlirSupportedHardware()` には gfx900 が残る一方、個別 solver 側で後段除外される | code_verified | `vega-rocm.md`, `final_hypothesis.md` |
| MLIR 強制実行 | 強制時は `CompileSolution` / `GetInvoker` まで進むが、Perf DB 不在と `MIIR_INVALID_PARAM` 系失敗を観測 | runtime_verified | `facts.md`, `trace_map_dynamic.md` |
| FP32 の旧経路 | gfx900 では FP32 で ASM / Winograd / legacy implicit GEMM 系の自然選択を観測 | runtime_verified | `vega-rocm.md`, `facts.md` |
| XDLops 系 | gfx900 では `IsXdlopsSupport() == false` 側に入り、物理制約で成立しない | code_verified / runtime_verified | `facts.md`, `final_hypothesis.md` |
| 観測した CK iGEMM path | 強制実行した CK iGEMM 系 path は全件 `not applicable` | runtime_verified | `gfx900_int8_path_inventory.md`, `trace_map_dynamic.md` |
| INT8 自然選択 | 探索した 15+ ケースでは `ConvDirectNaiveConvFwd` のみ自然選択された | runtime_verified | `facts.md`, `gfx900_int8_path_inventory.md` |
| 出荷成果物 | gfx900 向け rocBLAS 成果物、MIOpen Perf DB、vega10 firmware は現行環境で出荷を確認 | shipped_artifact_verified | `facts.md`, `support_boundary.md`, `final_hypothesis.md` |
| Tensile fallback | gfx900 関連 fallback / lazy loading 補修には外部 contributor 実績がある | history_verified | `provenance_map.md`, `community_vs_vendor_matrix.md`, `gfx900_history_timeline.md` |
| TheRock での扱い | `gfx900` は global target として残る一方、一部 project から selective exclude される | code_verified | `provenance_map.md`, `final_hypothesis.md`, `natural_maintenance_scenarios.md` |

---

## 2. 未確定事項（Unknowns）

| 論点 | 未確定な点 | 現時点で言える範囲 | 主な参照先 |
|---|---|---|---|
| private issue `llvm-project-private#389` | MLIR iGEMM 除外の技術的根拠そのもの | 公開側から確認できるのは参照関係と gate の痕跡のみ | `facts.md`, `final_hypothesis.md` |
| Perf DB 世代比較 | gfx900 と gfx1100/1200 の Perf DB 比較が公平か | gfx900 向け Find-DB 形式データ出荷は言えるが、世代間の手厚さ比較には留保が必要 | `facts.md`, `support_boundary.md`, `final_hypothesis.md` |
| RDNA 側 tuning mechanism | gfx1100/1200 が別の tuning 方式を主要経路にしているか | current 調査では未確認 | `final_hypothesis.md`, `provenance_map.md` |
| INT8 Perf DB | gfx900 向け Perf DB に INT8 エントリが含まれるか | gfx900 Perf DB 自体は存在するが、INT8 エントリ有無は未精査 | `gfx900_int8_path_inventory.md` |
| Winograd の INT8 | INT8 条件で Winograd 系が適用可能か | この調査では直接確認していない | `gfx900_int8_path_inventory.md` |
| ASM v4r1 の INT8 条件 | 自然選択で `Not applicable` になる主因が dtype / shape / 別条件のどれか | 強制 `1x1` は immediate まで進んで GPU fault する | `gfx900_int8_path_inventory.md`, `trace_map_dynamic.md` |
| 運用上のサポート | 現行 CI / bug triage / release 判定で gfx900 がどう扱われるか | 公開コードと出荷物は見えるが、内部 QA / triage は未確認 | `support_boundary.md`, `final_hypothesis.md` |
| TheRock の最終影響 | selective exclude が release / packaging policy にどう反映されるか | build / integration 層の構造までは確認済み | `final_hypothesis.md`, `natural_maintenance_scenarios.md` |

---

## 3. 現時点で安全に言えること

1. gfx900 は「完全に消えた target」ではなく、設計上の残存経路・出荷物・一部 fallback を持つ。
2. 一方で、MLIR iGEMM・XDLops・観測した CK iGEMM path など、成立しない経路も明確に存在する。
3. したがって、gfx900 の状態は「全面サポート」でも「完全消滅」でもなく、層ごとの時間差後退として読むのが最も整合的である。
4. 主体についても、「AMD が維持」か「コミュニティが維持」かの単純二分では足りず、投入主体・維持主体・修正可能主体を分けて読む必要がある。

---

## 4. 本文書の使い方

- 既知事項の確認だけが目的なら、この文書を先に見る
- 根拠の厚みが必要なら `facts.md` を見る
- 結論と含意を見たい場合は `final_hypothesis.md` を見る
- 主体分解や修正可能性を見たい場合は `provenance_map.md` / `community_vs_vendor_matrix.md` /
  `what_can_be_extended.md` / `what_cannot_be_extended.md` を見る

---

## 本文書が主張しないこと

- 未確定事項について推測で補完するものではない
- private issue の本文を再構成するものではない
- gfx900 の将来の扱いを予測するものではない
- 特定組織や個人への評価を目的とするものではない
