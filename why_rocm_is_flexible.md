# なぜ ROCm / MIOpen は一括削除されにくいのか

作成日: 2026-03-17
関連文書: `class_map.md`（責務アンカー）、`final_hypothesis.md` §2.2 / §5.1、`community_vs_vendor_matrix.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

`class_map.md` が「どこで何が起きるか」を固定したのに対し、
この文書は「**なぜその構造が柔軟性を生むのか**」を説明する。

対象読者:
- `final_hypothesis.md` の §2.2（capability-based 設計）/ §5.1（層単位の後退）を補強したい読者
- ROCm / MIOpen に保守参加を検討しているメンテナー候補

---

## 1. 登録と適用判定が分離されている

TODO

- solver の「登録」と「適用可否の判定」が分離されていることを説明する
- `SolverContainer` が全候補を列挙し、`SolverBase::IsApplicable()` が各自でフィルタする構造
- 含意: ある solver を「除外」しても他の solver に影響しない。個別撤退が構造的に容易

---

## 2. capability 判定が共通化されている

TODO

- `IsXdlopsSupport()` / `TargetProperties` などの共通 capability チェックが存在する
- arch 固有の条件は solver ごとに局所化されている
- 含意: 新 arch の追加・旧 arch の除外が、全 solver を一括変更せずに済む

---

## 3. solver ごとに個別撤退できる

TODO

- dtype 単位・layout 単位・arch 単位で `IsApplicable()` が独立しているため
  「FP32 は通るが INT8 は通らない」「gfx900 は通るが gfx908 の経路は別」という粒度の撤退が成立する
- gfx900 の Layered Retreat が「一括削除」ではなかった構造的理由
- 参照: `final_hypothesis.md` §2.5、`trace_map_static.md`

---

## 4. backend 接続が疎結合になっている

TODO

- MIOpen → rocMLIR の接続（`mlir_build.cpp`）、MIOpen → rocBLAS/Tensile の接続（`gemm_v2.cpp`）は
  それぞれ独立した接続点として局所化されている
- 参照: `class_map.md §他層との接続点`
- 含意: backend 側の変更が MIOpen solver 全体に波及しにくい

---

## 5. shipped artifact と code path が分離している

TODO

- コードベース上の「生存」と、出荷成果物（Perf DB / rocBLAS / firmware）の「残存」は独立した軸
- gfx900 は solver が IsApplicable で落とされても、Perf DB や rocBLAS プリコンパイル済みカーネルが残る
- 参照: `support_boundary.md §4層モデル`、`provenance_map.md §P8`
- 含意: 「コードを消す」と「出荷物を消す」は別の操作。後者は pipeline 側の判断

---

## 6. その結果として起きる Layered Retreat

TODO

- 上記 1〜5 の設計上の分離が重なることで、「component ごと・solver ごと・dtype ごとの時間差後退」が
  構造的に自然に発生する
- これは設計の意図であるかは観測できないが、少なくとも結果として観測される
- 参照: `final_hypothesis.md` §2.5 の Mermaid 図

---

## 本文書が主張しないこと

- この設計が「gfx900 のサポートを維持するために作られた」と断定するものではない
- 上記の柔軟性が「意図された設計方針」であると断定するものではない
- ROCm 全コンポーネントに同様の構造が存在すると一般化するものではない
- 特定組織や個人への評価を目的とするものではない
