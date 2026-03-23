# vega_investigations 査読ノート

査読日: 2026-03-24
方針: 疑義・誤り・証拠不足・内部矛盾のみ記載。正確な記述は記録しない。

---

## 1. installed MIOpen の provenance が未整理（複数ファイル横断）

**関係ファイル**: `gfx900_int8_path_inventory.md`、`dp4a_alternative_path.md`、`results/Vega64/20260319_miopendriver_build_provenance_followup.md`、`results/Vega64/20260320_installed_miopendriver_provenance.md`

少なくとも3系統の MIOpen が混在して言及されている：

- `ROCm-repos/MIOpen`（public standalone clone）
- `rocm-libraries/projects/miopen`（packaging-tree 系、「cast-aware driver family」と推定）
- `miopen-src@f842c61d`（local debug build）

結果ログの解釈時に「どの tree の挙動を観測したか」が曖昧なまま引用されているケースがある。`20260319_miopendriver_build_provenance_followup.md` で「exact source commit は未確定」と正直に書かれているにもかかわらず、他ファイルでは "installed driver" を単一実体として扱っている箇所がある。

**影響範囲**: `GemmFwd1x1_0_1_int8` の「CLI で不可 / direct query で可」の解釈、INT8 自然選択の観測結果の解釈いずれにも波及する。

---

## 2. MLIR iGEMM 強制実行の失敗メカニズムが未切り分け

**関係ファイル**: `vega-rocm.md`（行12付近）、`gfx900_int8_path_inventory.md`、`trace_map_static.md`、`trace_map_dynamic.md`

MLIR 強制実行の失敗として以下の2種が報告されているが、条件の違いが整理されていない：

1. `MIIR_INVALID_PARAM`（`miirLowerTuningParams` が返す）
2. Perf DB に tuning パラメータ不在 → `boost::optional::get()` assertion crash

「どちらが先に起きるか」「同一条件で両方起きるか」「条件によって一方だけか」が未切り分けのまま、下流の解釈ドキュメントでは両方を "gfx900 では MLIR が動かない証拠" として同列に引用している。失敗経路の因果を正確に説明するには切り分けが必要。

また `vega-rocm.md` では「FP32 でも同一パターンの crash を確認」と書かれているが、FP32 の具体ログが本文に存在しない。INT8 と同一パターンかどうかは「要確認」。

---

## 3. `GemmFwd1x1_0_1_int8` の分類が矛盾して見える

**関係ファイル**: `gfx900_int8_path_inventory.md`（行45、79-81）、`dp4a_alternative_path.md`

テーブル上で同一 solver が「`IsApplicable` 除外」かつ「solution query success（`y=int32` 直叩き）」に分類されている。

正確には「インターフェース層（CLI経由 vs direct query）によって露出・非露出が異なる」という話なのだが、それが明示されておらず、読者には「本当に Applicable なのか Not Applicable なのか」が判断できない。

`dp4a_alternative_path.md` 内でも「installer driver と current public standalone が同じ実装を持つか不明」という留保が途中で登場するが、この点が `gfx900_int8_path_inventory.md` の表には反映されていない。

---

## 4. rocBLAS/Tensile の INT8 backend への実到達が未確認のまま結論に近い書き方をしている箇所

**関係ファイル**: `gfx900_int8_path_inventory.md`（行52、71付近）、`fallback_chain_map.md`

現状の観測は：

- rocBLAS/Tensile INT8 artifact（`.dat/.hsaco`）: 存在確認済み
- backend 単体実行: 確認済み
- **MIOpen conv path → rocBLAS/Tensile INT8 backend: 未観測**

しかし `fallback_chain_map.md` 等でこの経路が「生きている可能性」として書かれる際、上記の「到達未確認」部分が十分に強調されていない箇所がある。INT8 自然選択が ConvDirectNaive のみという観測と、「backend は存在する」という観測をどう整合させるかも未記述。

---

## 5. vega-rocm.md section 11-12 が「実施済み」か「テンプレート」か不明

**関係ファイル**: `vega-rocm.md`（行583-656付近）

section 11「フォールバック判定チェックリスト」は詳細な手順が書かれているが、「これは調査計画・将来への手順書」なのか「実施済みの記録」なのかが不明。実施済みなら対応するログファイルへの参照がなく、テンプレートなら「未実施」と明記すべき。

---

## 6. Perf DB 行数比較の解釈が二重になっている

**関係ファイル**: `final_hypothesis.md`（行184-197）、`knowns_unknowns.md`（行47）

`final_hypothesis.md` では「gfx900 の Perf DB が多いことは find-db 形式への切り替えまたは AI-based tuning の可能性がある」と複数解釈を示す。一方 `knowns_unknowns.md` では「世代間の手厚さ比較には留保が必要」とのみ記載し、final_hypothesis 側の分析を参照していない。

どちらが canonical かが不明。読者が両方を参照すると解釈が揺れる。

---

## 7. INT8 Perf DB の有無が未確認のまま「Naive solver のみ自然選択」の説明に使われている

**関係ファイル**: `knowns_unknowns.md`（行48）、`gfx900_int8_path_inventory.md`（行96）

「INT8 自然選択が Naive solver のみ」という観測の原因として：

- (A) tuning パラメータ不在（Perf DB に INT8 エントリなし）
- (B) `IsApplicable` 条件でその他 solver が弾かれている

のどちらが主因かが未検証のまま。「INT8 Perf DB の抽出・同定は本調査で未実施」と書かれているが、(A) を確認せずに「Naive のみ」の観測を報告しているため因果が不完全。

---

## 8. 「設計判断 vs バグ回避」未確定がその後の議論の前提になっている

**関係ファイル**: `facts.md`（行90付近）、`vega-rocm.md`（行11）、`support_boundary.md`

MLIR iGEMM の gfx900 除外（commit `2407d2f`、参照 issue `llvm-project-private/issues/389`）について「設計判断かバグ回避か断定不可」と記録されている。

しかし `support_boundary.md` などでは「意図的なゲーティング」という表現が使われており、この言葉は "設計判断" 寄りのニュアンスを持つ。非公開 issue のため根拠が確認できない以上、「意図的」という表現はより強い断定に見え、留保との整合性が揺らぐ。

---

## 9. TheRock の gfx900 扱いを runtime packaging 反映として読んでいる

**関係ファイル**: `final_hypothesis.md`（§3.5）、`design_philosophy.md`（行163付近）

`final_hypothesis.md` では TheRock での gfx900 target の存在を「build 層での維持」の証拠として引用している。しかし `design_philosophy.md` 内に「TheRock は preview 段階」と記載があり、build 構造が実際の release package に反映されるかは保証されていない。

build 層での target 存在 = 出荷成果物への反映、とは限らないため、この引用は「build 構造上の観測」にとどめる表現が適切。

---

## 10. 観測のタイムスタンプが固定されており更新確認がない

**関係ファイル**: `facts.md`、`final_hypothesis.md`、`knowns_unknowns.md`

「shipped artifact 観測済み」「miopen-hip 7.2.0-1, build date 2026-01-30」などの観測は 2026-03-15〜17 時点のもの。この後に package 更新があったか確認されていない。「現在も出荷されている」と読める表現があるが、観測日時を超えた継続保証はない。

---

## 11. LLM推論スタックにおける MIOpen の位置づけの記述（要注意）

**関係ファイル**: `solver_architecture_map.md`、`fallback_chain_map.md`、`investigation_plan.md` など

MIOpen の solver 選択研究は `vega_investigations` の中核テーマであり、畳み込み workload への適用として有意義。ただし、**ollama/GGML 系 LLM 推論スタック**に対してこれらの知見を適用する文脈では注意が必要。

実機 strace（2026-03-24 実施、`ROCm-MI25-build/vega_path_check_logs/g4_summary_tinyllama_latest_20260324_005717.txt`）では、tinyllama 推論中に MIOpen ライブラリの openat は未観測。LLM 推論の主経路は rocBLAS/Tensile であり、MIOpen の solver 選択研究をそのまま LLM 推論改善の文脈で語ると誤解を招く。

`vega_investigations` 内の各ドキュメントが「MIOpen は convolution workload の話」と明示していれば問題ないが、文脈なしに引用された場合に LLM 推論への誤用が起きうる。読む側が注意を要する点として記録しておく。

---

## 要約テーブル

| # | ファイル（代表） | 問題の種類 | 重大度 |
|---|---|---|---|
| 1 | gfx900_int8_path_inventory.md 他 | installed MIOpen provenance 未確定・系統混在 | 高 |
| 2 | vega-rocm.md、trace_map_*.md | MLIR 失敗メカニズム2種の切り分け不足 | 中 |
| 3 | gfx900_int8_path_inventory.md | GemmFwd1x1_0_1_int8 の分類が矛盾して見える | 中 |
| 4 | fallback_chain_map.md 他 | INT8 backend 実到達未確認なのに強めの書き方 | 中 |
| 5 | vega-rocm.md sec.11-12 | 「実施済み」か「テンプレート」か不明 | 低〜中 |
| 6 | final_hypothesis.md / knowns_unknowns.md | Perf DB 行数解釈が二重で canonical 不明 | 低 |
| 7 | knowns_unknowns.md 他 | INT8 Perf DB 有無未確認のまま因果説明 | 中 |
| 8 | facts.md / support_boundary.md | 「設計判断 vs バグ回避」未確定なのに強い表現使用 | 低〜中 |
| 9 | final_hypothesis.md | TheRock build 構造 → runtime packaging と読める | 低 |
| 10 | facts.md 他 | 観測タイムスタンプ固定・更新確認なし | 低 |
| 11 | solver_architecture_map.md 他 | MIOpen 知見を LLM 推論文脈で使う際の誤用リスク | 低（注意点） |
