# support / intent を公開履歴からどこまで読めるか

作成日: 2026-03-17
関連文書: `rocm-github-investigate.md`, `provenance_map.md`, `gfx900_history_timeline.md`, `community_vs_vendor_matrix.md`, `final_hypothesis.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 目的

`gfx900` について、

- 「AMD は何を止めたのか」
- 「何を残したのか」
- 「support の意図をどこまで公開履歴から読めるのか」

を、**履歴上の証拠だけで**切り分ける。

本メモの役割は、`final_hypothesis.md` や `support_meaning_conclusion.md` が
support / intent の話をするときに、
「公開履歴からここまでは言える、ここから先は言えない」という境界を固定することにある。

---

## 1. 公開履歴から確認できること（Fact）

### 1.1 component ごとの明示的 disable は確認できる

- MIOpen MLIR iGEMM については、`2407d2f` / legacy `d1a42ea69e` により
  `gfx900` を non-xdlops solver から明示除外したことが確認できる。
- 公開 PR `ROCm/MIOpen#1328` では、ROCm 5.1 向けの調整と test 側の無効化も見える。
- したがって、少なくとも **MLIR iGEMM については AMD 側の明示的な selective disable**
  が public history から確認できる。

### 1.2 legacy path 側の補修も確認できる

- ASM v4r1 dynamic には `gfx900/gfx906` 専用 allow 条件が投入時点から存在する。
- Winograd 系には 2021-2023 に bug fix / perf workaround が入っている。
- Tensile には `gfx900:xnack-` 追加や fallback libraries 方針の再投入が見える。
- したがって、公開履歴は **「止める変更」だけでなく「残る経路への補修」** も示している。

### 1.3 source-build / community 向けの public stance は一部確認できる

- Tensile `#1595` では、gfx900 対応が
  「AMD 公式 binary に直結しないが、source-build user には有用」
  という趣旨で説明されている。
- これは `gfx900` が public OSS 層ではなお調整対象になりうることを示す。
- ただし、これは **source-build / community 運用層** に関する観測であり、
  product-level support の宣言ではない。

### 1.4 shipped artifact の残存は確認できる

- ROCm 7.2 実パッケージには、gfx900 向け rocBLAS code object、MIOpen Perf DB、
  vega10 firmware が残っている。
- current `TheRock` でも、`gfx900` は global target として登録されつつ、
  一部 project だけ `EXCLUDE_TARGET_PROJECTS` で filter される。
- したがって、build / packaging 層でも **全面削除ではなく selective exclude**
  が観測される。

### 1.5 public history から repo-wide な「全面削除提案」は回収できていない

- local clone 上で `MIOpen` / legacy `MIOpen` / legacy `Tensile` に対し、
  `gfx900`, `Vega`, `remove`, `disable`, `drop` を軸に `git log --grep` を再確認した。
- その結果、component 単位の disable / workaround / fallback 変更は回収できたが、
  **`gfx900` 全体を public に一括削除する提案** は現時点で回収できていない。
- 少なくとも local public history の範囲では、
  観測されるのは **component ごとの後退** であり、
  repo-wide な一括撤去提案ではない。

---

## 2. 公開履歴から直接は言えないこと（Limitation）

### 2.1 private issue #389 の理由

`llvm-project-private#389` は非公開であり、本文は確認できない。
ここから言えるのは、公開コード側に参照関係と gating の痕跡があるという範囲に限られる。

したがって、次は断定できない。

- なぜ gfx900 を disable したのか
- 一時停止なのか、恒久除外なのか
- どのチームのどの判断だったのか

### 2.2 shipped artifact の残存を「積極的 support 意図」とは断定できない

Perf DB、rocBLAS code object、firmware が出荷されていること自体は事実である。
しかし、それだけで

- QA 対象だった
- 優先修正対象だった
- 公式に維持する意図があった

とまでは言えない。

公開側から確認できるのは **配布層に残存がある** という事実までである。

### 2.3 「全面削除提案が見つからない」ことは「削除意思がなかった」の証明ではない

public history から repo-wide な削除提案を回収できていないことは事実だが、
それは次を意味しない。

- 内部で議論がなかった
- private issue / private planning が存在しなかった
- maintainer 側に削除意思がなかった

観測できるのは、**公開履歴に表れた範囲では全面削除 proposal が見えない**
という点までである。

---

## 3. 履歴から読める support / intent の最小結論（Interpretation）

### 3.1 public history が支持するのは「layered retreat」である

公開履歴は、`gfx900` について次のような非対称な変化を示している。

| 層 | 観測される変化 |
|---|---|
| solver / compiler | MLIR iGEMM で明示 disable |
| legacy solver | ASM v4r1 / Winograd に残存と補修 |
| library fallback | Tensile fallback の再投入と revert 混在 |
| build / packaging | shipped artifacts 残存、TheRock で selective exclude |

この並びは、「一括削除」よりも
**component ごとの時間差後退** と読む方が公開事実に整合する。

### 3.2 public history だけでは「意図」より「構造」の方が強く言える

公開履歴から比較的強く言えるのは、

- selective disable があること
- 残存経路への補修があること
- source-build / community 向けの余地が一部残ること
- packaging/build 層に残存があること

である。

逆に、

- AMD が全体としてどう考えていたか
- support をどの層で終了とみなしていたか
- どこまでが product policy だったか

は公開履歴だけでは閉じない。

そのため、少なくとも公開側からは、
**support 意図を一本線で再構成するより、層ごとの観測を積む方が安全**
と読める。

### 3.3 「AMD が切った」対「コミュニティが支えた」の二分では足りない

public history を経路ごとに見ると、

- P1 MLIR iGEMM 除外は AMD(M)
- P2/P3 legacy solver は AMD 起源だが残存と補修が混在
- P6 Tensile fallback は external contributor の寄与が大きい
- P8 shipped artifacts は build pipeline / distribution 層の観測

となり、主体は単線化できない。

したがって、support / intent を読むときは
`provenance_map.md` の
**投入主体 / 維持主体 / 運用主体 / 修正可能主体**
の分解を保った方が誤読が少ない。

---

## 4. 「削除提案があったか」への現時点の答え

### Fact

local public clone の履歴確認では、
**`gfx900` 全体を public に一括削除する提案** は現時点で回収できていない。

### Fact

一方で、component 単位では明示的な disable / 後退 / default build からの除外は観測される。

### Interpretation

したがって、公開履歴から最も安全に言えるのは次である。

> `gfx900` について public history が示しているのは、
> repo-wide な全面削除 proposal よりも、
> component ごとの selective disable と layered retreat である。

### Limitation

これは private planning や internal decision を否定するものではない。
公開側からはそこまでは確認できない。

---

## 本文書が主張しないこと

- AMD の社内意思決定過程を再構成するものではない
- private issue の本文を推定で補完するものではない
- public history に全面削除 proposal が見えないことをもって、削除意思がなかったと断定するものではない
- shipped artifact の残存をそのまま product-level support 意図とみなすものではない
- 特定組織や個人への批判を目的とするものではない
