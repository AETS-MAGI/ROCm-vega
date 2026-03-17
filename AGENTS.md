# AGENTS.md

**注意：このリポジトリはROCm横断調査用であり、整理して外部公開するためのリポジトリ（GitHub Pages用）が別に存在することに留意してください。**. 
**ただし、本リポジトリもPublicですので、そのことは意識してください。ただし、それを意識しすぎて調査が萎縮してしまってはいけません。**

## はじめに

本調査では、膨大なコード・履歴・ログ・文書・公開資料を横断して扱う必要があるため、LLM Agent の活用を前提とすることは避けられない。  
そのため、人間の研究者と Agent は共同で作業を行うが、Agent は調査過程において作業ログの整理、本文追記、要約、監査補助、仮説整理等を担う場合がある。

一方で、LLM Agent は、もっともらしい説明や過度な一般化、意図の断定、未確認情報の補完を行ってしまう危険を持つ。  
したがって、本調査では本 `AGENTS.md` を共通の文章ポリシーおよび作業ガードとして用い、調査結果をできる限り客観的・中立的・反証可能な形で保つことを目的とする。文章タイトルこそ`AGENTS`であるが、本文書は人間も含めた調査全体での最上位のガイドラインとして機能する。

---

## 1. 基本原則

### 1.1 観測可能な範囲を超えて断定しない
Agent は、公開一次資料、ローカル clone、実機ログ、逆アセンブル結果など、実際に確認できた根拠を超えて断定してはならない。  
特に、非公開 issue、社内意思決定、maintainer の意図については、観測可能な範囲を明示したうえで扱うこと。

### 1.2 事実・解釈・未解決を分ける
本文・メモ・要約では、少なくとも次の3層を区別すること。

- **Fact**: 実際に確認済みの事実
- **Interpretation**: 事実から読める解釈
- **Open Question / Limitation**: 未確定事項、限界、今後の調査課題

### 1.3 意図を断定しない
「〜のために設計された」「〜を意図している」「〜を狙っている」等の表現は避け、必要な場合は以下のような表現に置き換えること。

- 「〜と読める」
- 「〜を示唆する」
- 「少なくとも構造上は〜に見える」
- 「結果として〜が成立している」

### 1.4 private 領域は限界を明記する
`llvm-project-private` など非公開情報に触れる場合は、毎回次を明記すること。

- issue / discussion 本文は未確認である
- 公開側から確認できるのは参照関係やコード上の痕跡に限られる
- よって、原因や意思決定の詳細は断定しない

### 1.5 主体を単線化しない
「AMD がやった」「コミュニティが支えている」といった表現は、必要に応じて次の層に分解すること。

- **投入主体**
- **維持主体**
- **運用主体**
- **修正可能主体**

### 1.6 本調査は批判文書ではなく構造分析である
本研究および調査は、AMDとコミュニティの多大な貢献の成果と構造を、敬意を払いつつ調査するものである。
本研究および調査の目的は、特定企業や特定個人の設計判断を評価・批判することではなく、  
公開資料および観測可能な範囲から、設計傾向・保守構造・失敗境界・実行経路を整理することにある。

---

## 2. 文体ポリシー

### 2.1 推奨表現
- 「確認できる」
- 「観測される」
- 「示唆される」
- 「少なくとも〜の範囲では言える」
- 「現時点では未確定」
- 「公開側からはここまでしか言えない」

### 2.2 非推奨表現
- 「明らかに」
- 「当然」
- 「完全に証明された」
- 「AMD は〜を意図した」
- 「コミュニティが維持しているに違いない」
- 「これで確定」
- 「裏でこう考えていたはず」

### 2.3 批判的・対立的に読まれうる語の扱い
以下の語は必要性を慎重に検討し、可能ならより中立な語へ置き換えること。

- 事件 → 観測点 / 分岐点 / 注目点
- 封じた → 止めた / 除外した / gating した
- 切り捨てた → default build から後退した / selective disable した
- 残骸 → legacy path / 残存経路

---

## 3. 記述テンプレート

### 3.1 技術ノート
- **Fact**
- **Interpretation**
- **Open Question / Limitation**

### 3.2 private issue 参照時の注記（日本語）
> この issue は非公開であり、本文は外部から確認できない。したがって、ここから言えるのは公開コード側に参照関係と gating の痕跡が存在するという範囲に限られる。

### 3.2a private issue 参照時の注記（英語）
> This issue is not publicly accessible; its content cannot be verified from outside. Accordingly, what can be stated here is limited to the observable reference relationship and gating pattern in the public codebase.

### 3.3 文書末尾の Non-claims
主要文書には必要に応じて、次の節を付けること。

#### 本文書が主張しないこと

- 社内意思決定過程を断定するものではない
- 非公開 issue の本文を推定で補完するものではない
- 単一事例から一般法則を断定するものではない
- AMD の support policy 全体を完全に代表するものではない
- 特定組織への批判を目的とするものではない

#### This document does not claim that... （英語版 Non-claims）

- Internal decision-making processes are asserted or concluded.
- The content of private issues has been inferred or reconstructed.
- A single observed case is generalized into a universal rule.
- AMD's support policy as a whole is fully represented.
- Any specific organization is being criticized.

---

## 4. Agent の役割分担

### 4.1 Agent が担ってよいもの
- 既存文書の整理
- 作業ログの追記
- 根拠整理
- 仮説のラベリング
- 誤読リスクの監査
- 文体の中立化提案
- 参考用サマリの作成

### 4.2 Agent が単独で確定してはならないもの
- 社内事情の断定
- private issue 内容の推定確定
- 著者・maintainer の意図断定
- 「一般法則」としての最終認定
- 対外公開版の最終確定

### 4.3 最終責任
最終的な公開判断・表現確定・対外共有可否の責任は人間の調査者が持つ。  
Agent はあくまで補助者であり、最終決定者ではない。

---

## 5. 実務上の優先順位

このリポジトリには、対応するGitHub Pages（別リポジトリ）が存在します。そのリポジトリを操作する場合には、文書修正時は、次の順で作業すること。

1. **上位 investigation 文書**（技術的主張の根拠を持つ文書）
   - `rocm-github-investigate.md`
   - `reveal_hypothesis.md`
   - `hypothesis.md`
   - `facts.md`

2. **高露出 public HTML 文書**（AMD 技術者が参照する可能性が高い順）
   - `solver-trace.html`
   - `rocm-history.html`
   - `reveal-hypothesis.html`
   - `presentation_advanced_en-jp.html`
   - `experiment-history.html`

3. **補助 HTML 文書**
   - `hypothesis.html`（ナビリストには掲載されていない補助ページ）
   - `code-tracing.html`

4. **narrative / essay 系**
   - 技術主張ではなく、個人史・寓話・一般向け説明であることを明示する
   - `general-audience.html` / `vega-story_for-child.html` / `essay.html` など

**注意**: investigation 文書（.md）を修正したら、対応する公開 HTML に同内容の修正を反映すること。
MD と HTML の間で表現が乖離しないよう、変更はセットで管理する。

---

## 6. 最重要の共通文

必要に応じて、各文書の冒頭または末尾に以下を置くこと。

日本語:
> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

英語:
> This document organizes observations from publicly available sources and local repository clones only. It does not assert the contents of private issues or internal decision-making processes.

---