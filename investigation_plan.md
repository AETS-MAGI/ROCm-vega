# ROCm / Vega(gfx900) 調査計画
## 設計思想・実装構造・履歴・動的経路から「本当の意味でのサポート」を読むために

## 1. 目的

本調査の目的は、単に **「Vega / gfx900 が今も動くかどうか」** を確認することではない。  
本当に明らかにしたいのは、以下の問いである。

1. **ROCm はどの層で、どの程度まで旧世代 GPU を支えうる設計になっているのか**
2. **gfx900 の生存は、偶然の残骸なのか、設計上自然に残る経路なのか**
3. **コミュニティはどの層を現実的に保守でき、どの層は難しいのか**
4. **将来の統合・再統合・抽象化の観点から、どこが「サポートの筋」なのか**

本調査では、表面的な「対応 / 非対応」ではなく、  
**設計思想・コード構造・実行経路・履歴・運用可能性** を重ね合わせて、  
ROCm におけるサポートの実質を読みにいく。

---

## 2. 背景と問題意識

近年の日本語 LLM 評価においては、結果そのものよりも **評価基盤の再現性** が重要な問題になっている。  
りもこの総合大会原稿でも、DeepSeek R1 の MoE / MLA のような構造的特性を、単なるモデルの特徴ではなく **「実行環境差が顕在化しやすい評価軸」** として扱う立場が明示されている。 :contentReference[oaicite:1]{index=1}

この考え方を ROCm / Vega 調査に拡張すると、見るべきものは単なる性能値ではなく、

- どの層で差異が吸収されるのか
- どの層で capability によって分岐するのか
- どの層で fallback が発動するのか
- どの層がコミュニティにより維持可能か

という **構造そのもの** である。

---

## 3. 基本仮説

### 仮説A: 表のサポートと設計上のサポートは別である

Vega / gfx900 は現在の「主要サポート対象」としては弱い。  
しかしコードベース上では、なお複数の実行経路・fallback 経路が残っている可能性が高い。

### 仮説B: gfx900 の生存は「完全な偶然」ではなく、設計の副産物として自然に説明できる

MIOpen, rocBLAS / Tensile, CK などの複数層で、

- capability 判定
- solver 列挙
- fallback
- backend 切替

が存在することから、**旧世代が通れる設計の筋** があると考えられる。

### 仮説C: コミュニティが握れるのは主に OSS 層であり、そこではかなり強い

ドライバやファームウェア等の境界は別問題としても、

- userspace library
- solver registry
- capability table
- fallback logic
- trace / logging / CI
- build system

などの層は、コミュニティによる解析・補修・保守の余地が大きい。

### 仮説D: 「本当の意味でのサポート」は、設計思想と履歴の両方に現れる

サポートとは単に「コードがあること」ではない。  
本当に見るべきなのは、

- なぜ残ったのか
- どの責務層に置かれているのか
- 誰が維持してきたのか
- それを消すと何を巻き込むのか

である。

### 仮説E: 将来の再統合を低コストで行うなら、どこかに共通化の筋が残っているはずである

UDNA の本質そのものは現時点では断言できない。  
しかし、将来の再統合コストを下げるためには、**結果として後方互換や抽象化の筋をどこかに残しておくのが合理的** である。  
現時点のコードベース調査は、少なくとも **「そう読めるだけの構造が存在する」** ことをかなり強く支持している。

---

## 4. 調査対象の層構造

本調査は、以下の 6 層に分けて行う。

1. **思想層**  
   ROCm 全体がどのような設計哲学で作られているか
2. **構造層**  
   クラス構造・責務分離・抽象化の置き方
3. **経路層**  
   実際にどの条件でどの solver / backend / kernel が選ばれるか
4. **履歴層**  
   誰が・いつ・なぜそのコードを入れた / 残した / 削ったか
5. **境界層**  
   コミュニティで支えられる範囲と、そうでない範囲
6. **含意層**  
   今後どこまで維持できるか、どこが限界か、何が可能か

---

# 5. 層ごとの調査計画

## 5.1 思想層: ROCm の設計思想調査

### 目的
ROCm がそもそも

- 特定世代専用最適化の寄せ集めなのか
- 差異吸収・抽象化・後方互換を重視した設計なのか

を見極める。

### 調査対象
- ROCr / HIP / MIOpen / rocBLAS / Tensile / CK の全体構造
- capability 判定の置き方
- backend 切替の方式
- solver finder の考え方
- front-end API の抽象度

### 見るポイント
- 世代差が `if (gfx == xxx)` のベタ書きで散らばっているか
- それとも属性・能力・戦略オブジェクトで吸収されているか
- 「速い経路」と「広く通る経路」が分離されているか
- backend / solver の選定が一般化されているか
- API が hardware-specific か hardware-agnostic か

### 成果物
- `design_philosophy.md`
- `abstraction_layers.md`
- `support_model_hypothesis.md`

---

## 5.2 構造層: クラス構造・責務分離・抽象化マッピング

### 目的
**どこが何を担当しているか** を明確化し、  
どの層で差分を吸収しているのかを読む。

### 調査内容
- クラス / 構造体 / namespace の整理
- 継承関係
- interface / implementation の分離
- registry / factory / strategy pattern の有無
- solver 登録テーブルの関係
- target properties / ISA capability / device info の流れ

### 具体的にやること
- C++ コードベース全体を対象に、以下を抽出する
  - device 情報を持つ型
  - capability 判定を行う型
  - solver finder / registry を担う型
  - backend 選定を担う型
  - kernel 発行を担う型
- 継承図 / 依存図 / 呼び出し図を作る
- `gfx900` に関係する分岐が、どの責務層に置かれているか分類する

### 成果物
- `class_map.md`
- `solver_architecture_map.md`
- `device_capability_flow.md`
- `gfx900_related_nodes.md`

---

## 5.3 経路層: 静的経路調査

### 目的
**コード上で、何がどこで弾かれ、どこへ流れるか** を明示する。

### 調査内容
- MIOpen の候補列挙 → `IsApplicable` → 実行までの追跡
- rocBLAS → Tensile → code object 選択の流れ整理
- CK / legacy CK の capability 分岐整理
- front-end API から最終 kernel までの静的 call chain 図化

### 観測したいこと
- gfx900 がどの段階で落ちる / 残るのか
- どの経路が主経路で、どれが縮退運転経路なのか
- DP4A 非対応時の代替設計がどうなっているか

### 成果物
- `trace_map_static.md`
- `fallback_chain_map.md`
- `solver_selection_graph.md`
- `dp4a_alternative_path.md`

---

## 5.4 経路層: 動的トレース調査

### 目的
静的に存在する経路が、**実際に実機で選ばれているか** を確認する。

### 調査内容
- MIOpen logging による solver 選択確認
- rocBLAS trace による Tensile 実行痕跡確認
- `rocprofv3` による kernel trace
- HSACO 逆アセンブルによる命令確認
- gfx900 と比較世代での経路差比較

### 観測したいこと
- `ConvAsmImplicitGemmV4R1Dynamic*` が本当に選ばれるか
- `ConvMlirIgemm*` が本当に落ちるか
- DLOPS 系がどの条件で生きるか
- INT8 実行時に `v_dot4_i32_i8` が出るか / 出ないか
- 出ないのに動くなら、代替積和経路に落ちているか

### 成果物
- `trace_map_dynamic.md`
- `solver_observation_log.md`
- `hsaco_disassembly_notes.md`
- `gfx900_vs_gfx90a_diff.md`

---

## 5.5 履歴層: provenance / maintainer / コミュニティ調査

### 目的
**なぜコードが残っているのか** を、履歴から読む。

### 調査内容
- `git blame`
- commit message
- PR / issue / review comments
- author / maintainer / external contributor の区別
- 削除提案の有無
- 維持理由の明示有無

### 見るポイント
- `gfx900` 関連行は誰が入れたか
- その変更は AMD 社員由来か外部貢献か
- 「互換維持」「legacy support」「fallback」などの意図があるか
- 「unsupported」「削除提案」などの議論があるか
- maintainer が残置を容認しているだけか、積極維持しているか

### 成果物
- `provenance_map.md`
- `gfx900_history_timeline.md`
- `support_intent_notes.md`
- `community_vs_vendor_matrix.md`

---

## 5.6 境界層: コミュニティ保守可能範囲の明確化

### 目的
**どこまでならコミュニティが“実質サポート”を握れるか** を整理する。

### コミュニティが比較的握りやすい層
- userspace library
- solver registry
- fallback logic
- capability table
- build system
- trace / benchmarking / CI
- front-end wrapper / runner

### 握りにくい層
- カーネルモードドライバ
- firmware / microcode
- 公式 QA マトリクス
- 製品保証
- リリース判定

### 調査内容
- 各層の依存関係整理
- userspace だけで延命可能な範囲の明示
- kernel / firmware 境界の制約整理
- コミュニティサポートがどこまで現実的かの記述

### 成果物
- `support_boundary.md`
- `community_maintainable_layers.md`
- `non_community_layers.md`

---

## 5.7 含意層: 今後どう維持されるのが自然か

### 目的
ここまでの調査結果から、**将来どの方向が自然か** を論理的に描く。

### 検討する問い
- 現状の設計で自然に残るのはどの層か
- 消えるならどの層から消えやすいか
- 再統合や抽象化の観点から、どこが重要な接点か
- 将来的にコミュニティが押さえるべき層はどこか
- gfx900 のような旧世代が残ることは「設計の歪み」か「設計の寛容性」か

### 成果物
- `future_support_paths.md`
- `natural_maintenance_scenarios.md`
- `what_can_be_extended.md`
- `what_cannot_be_extended.md`

---

# 6. 調査手法

## 6.1 静的調査
- `rg` / `git grep`
- clangd / ctags / cscope
- AST / include / call graph 生成
- C++ class hierarchy 抽出
- solver registry / capability table の一覧化

## 6.2 動的調査
- MIOpen logging
- rocBLAS trace
- `rocprofv3`
- HSACO 逆アセンブル
- 比較 GPU での差分観測

## 6.3 履歴調査
- `git blame`
- `git show`
- `gh search prs/issues`
- PR / issue / review 分析
- contributor / maintainer 属性整理

## 6.4 文書化ルール
各観測を以下で分類する。

- `code_verified`
- `runtime_verified`
- `history_verified`
- `hint_only`
- `hypothesis`
- `out_of_scope`

---

# 7. 調査順序

## Phase 1: 既存観測の固定
- 既存メモを canonical 化
- 主要経路と主要仮説の一覧化
- `trace_map_static.md` の骨組み作成

## Phase 2: 構造調査
- クラス・責務・継承・依存関係の可視化
- device / capability / solver / backend の流れ整理

## Phase 3: 動的検証
- 実機ログ
- solver 選択
- kernel trace
- HSACO 逆アセンブル

## Phase 4: 履歴調査
- `git blame`
- commit / PR / issue 追跡
- provenance map 作成

## Phase 5: 境界と含意の整理
- コミュニティ保守可能範囲
- 将来シナリオ
- サポートの筋の明文化

---

# 8. 最終的に答えたい問い

## Q1. Vega / gfx900 はなぜ今も生きているのか
- 偶然か
- 後方互換の副産物か
- 抽象化設計の自然な結果か

## Q2. ROCm は何をどうサポートしているのか
- 表向きの推奨対象
- 実装上の生存可能範囲
- コミュニティが握れる範囲

## Q3. 「サポート終了」とは本当は何を意味するのか
- ドキュメント上の切り離し
- QA / 保証の終了
- userspace 経路の消滅
- kernel / firmware 境界の断絶

## Q4. コミュニティはどこまで実質サポートを成立させられるか
- 何を守れるか
- 何は守れないか
- どの層を押さえると強いか

## Q5. 将来の再統合や共通化に対して、いま見えている構造は何を意味するか
- 多段 fallback
- capability 吸収
- backend 分離
- 抽象化の太さ
- 旧世代残存の意味

---

# 9. 本調査の位置づけ

この調査は単なる「古い GPU を動かして遊ぶ話」ではない。  
むしろ、

- **構造的特性を評価軸として扱う**
- **環境差を可視化する**
- **再現可能な検証基盤の上で議論する**

という、りもこの既存研究方針の延長線上にある。  
つまりこれは、  
**Vega / gfx900 の延命調査** であると同時に、  
**ROCm の設計思想とサポート実態の研究** でもある。 :contentReference[oaicite:2]{index=2}

---

# 10. ひとことで言うと

この計画の核心はこうである。

> 「動くかどうか」ではなく、  
> **どの層で、どんな思想のもとに、どのような経路が残り、誰によって維持され、どこまで支えられるのか**  
> を明らかにする。

これができると、  
**表のサポート** と **本当の意味でのサポート** を分けて語れるようになる。