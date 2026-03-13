# ROCm / Vega(gfx900) 調査 TODO
## 「本当の意味でのサポート」を読むための実行タスク一覧

---

## 0. 事前準備

- [ ] 調査対象リポジトリ一覧を確定する
  - [ ] ROCm
  - [ ] HIP
  - [ ] ROCr
  - [ ] MIOpen
  - [ ] rocBLAS
  - [ ] Tensile
  - [ ] Composable Kernel (CK)
- [ ] ローカル作業ディレクトリを作成する
- [ ] 各リポジトリを clone する
- [ ] 調査結果保存用ディレクトリを作る
  - [ ] `notes/`
  - [ ] `artifacts/`
  - [ ] `logs/`
  - [ ] `history/`
  - [ ] `graphs/`
- [ ] 観測分類ルールを決める
  - [ ] `code_verified`
  - [ ] `runtime_verified`
  - [ ] `history_verified`
  - [ ] `hint_only`
  - [ ] `hypothesis`
  - [ ] `out_of_scope`

---

## 1. 既存観測の固定

- [ ] 既存メモを canonical な調査メモに統合する
- [ ] 既知の主要仮説を一覧化する
- [ ] 既知の主要経路を一覧化する
- [ ] 既知の未確定事項を一覧化する
- [ ] `trace_map_static.md` の初版を作る
- [ ] `knowns_unknowns.md` を作る

### 既知事項として固定したいもの
- [ ] gfx900 向け solver / backend 経路の残存
- [ ] MLIR iGEMM が gfx900 を明示除外していること
- [ ] ASM implicit GEMM 系の生存
- [ ] Tensile 側の capability / fallback の存在
- [ ] DP4A / dot4 非対応時の代替経路候補

---

## 2. 思想層調査

### 2.1 ROCm 全体思想の把握
- [ ] ROCm 全体のレイヤ構造を整理する
- [ ] ROCr / HIP / MIOpen / rocBLAS / Tensile / CK の責務を一文で定義する
- [ ] 各コンポーネントが「抽象化」「最適化」「互換性」のどれを主に担当するか整理する

### 2.2 設計思想の観点で見る
- [ ] 世代差吸収が capability ベースか、個別分岐ベースかを確認する
- [ ] 「速い経路」と「広く通る経路」が分離されているか確認する
- [ ] backend 切替が一般化されているか確認する
- [ ] front-end API が hardware-agnostic か確認する
- [ ] fallback が場当たり対応か設計の一部かを判定する

### 成果物
- [ ] `design_philosophy.md`
- [ ] `abstraction_layers.md`
- [ ] `support_model_hypothesis.md`

---

## 3. 構造層調査

### 3.1 型・責務の洗い出し
- [ ] device 情報を持つクラス / 構造体を抽出する
- [ ] capability 判定を行う型を抽出する
- [ ] solver finder / registry を担う型を抽出する
- [ ] backend 選定を担う型を抽出する
- [ ] kernel 発行を担う型を抽出する

### 3.2 依存関係の整理
- [ ] 継承関係を可視化する
- [ ] interface / implementation 分離を整理する
- [ ] registry / factory / strategy pattern の有無を確認する
- [ ] target properties → capability → solver → kernel の流れを図にする

### 3.3 gfx900 関連構造の特定
- [ ] `gfx900` を参照する箇所を全件列挙する
- [ ] `vega` を参照する箇所を全件列挙する
- [ ] `dot4` / `dp4a` を参照する箇所を列挙する
- [ ] `fallback` を参照する箇所を列挙する
- [ ] `IsApplicable` / `Applicable` / `Not applicable` 系の箇所を列挙する
- [ ] 各箇所を責務層ごとに分類する

### 成果物
- [ ] `class_map.md`
- [ ] `solver_architecture_map.md`
- [ ] `device_capability_flow.md`
- [ ] `gfx900_related_nodes.md`

---

## 4. 静的経路調査

### 4.1 MIOpen 系
- [ ] solver 列挙起点を見つける
- [ ] `IsApplicable` の呼び出し連鎖を追う
- [ ] gfx900 を通す条件を列挙する
- [ ] gfx900 を弾く条件を列挙する
- [ ] MLIR iGEMM 系の除外条件をまとめる
- [ ] ASM implicit GEMM 系の通過条件をまとめる
- [ ] DLOPS / Winograd / legacy solver の条件を整理する

### 4.2 rocBLAS / Tensile 系
- [ ] rocBLAS から Tensile に渡る入り口を特定する
- [ ] Tensile backend 選択条件を整理する
- [ ] lazy loading / fallback code object の条件を整理する
- [ ] hipBLASLt → Tensile fallback 条件を整理する
- [ ] XF32 → FP32 fallback 条件を整理する

### 4.3 CK 系
- [ ] CK 側の architecture / capability 判定を整理する
- [ ] legacy CK の扱いを整理する
- [ ] dot4 有無に関する分岐を整理する

### 4.4 front-end からの流れ
- [ ] ユーザーが呼ぶ API / 関数を特定する
- [ ] front-end API から solver/backend 選択までの call chain を図にする
- [ ] 「ユーザーに何を隠しているか」を整理する

### 成果物
- [ ] `trace_map_static.md`
- [ ] `fallback_chain_map.md`
- [ ] `solver_selection_graph.md`
- [ ] `frontend_to_kernel_map.md`
- [ ] `dp4a_alternative_path.md`

---

## 5. 動的トレース調査

### 5.1 実行ログの準備
- [x] MIOpen logging の有効化方法を整理する
- [ ] rocBLAS trace の有効化方法を整理する
- [ ] `rocprofv3` の使用方法を整理する
- [x] HSACO 抽出 / 逆アセンブル手順を整理する

### 5.2 実行確認
- [x] gfx900 実機で対象ケースを再現する
- [ ] 比較用 GPU で同一ケースを再現する
- [x] solver 選択ログを保存する
- [ ] kernel trace を保存する
- [x] 実行時 environment を保存する

### 5.3 命令確認
- [x] HSACO を抽出する
- [x] `llvm-objdump` で逆アセンブルする
- [x] `v_dot4_*` の有無を確認する
- [x] `mul/add/mac/mad` 系の代替積和命令列を確認する
- [ ] gfx900 と比較世代で差分を取る

### 5.4 重点確認項目
- [ ] `ConvAsmImplicitGemmV4R1Dynamic*` が本当に選ばれるか確認する
- [ ] `ConvMlirIgemm*` が実際に落ちるか確認する
- [ ] DLOPS 系がどの条件で通るか確認する
- [x] dot4 非対応時に代替経路へ落ちるか確認する

### 成果物
- [ ] `trace_map_dynamic.md`
- [ ] `solver_observation_log.md`
- [ ] `hsaco_disassembly_notes.md`
- [ ] `gfx900_vs_other_gpu_diff.md`

---

## 6. 履歴層調査

### 6.1 blame / commit 調査
- [ ] `gfx900` 関連行の `git blame` を取る
- [ ] `vega` 関連行の `git blame` を取る
- [ ] `fallback` 関連行の `git blame` を取る
- [ ] `dot4` / `dp4a` 関連行の `git blame` を取る
- [ ] `IsApplicable` 重要箇所の `git blame` を取る

### 6.2 commit 意図調査
- [ ] 対象 commit message を収集する
- [ ] 各 commit の diff を読む
- [ ] 各 commit を意図別に分類する
  - [ ] 互換維持
  - [ ] fallback 追加
  - [ ] 最適化追加
  - [ ] バグ修正
  - [ ] ビルド修正
  - [ ] 削除 / 切り離し
  - [ ] 不明

### 6.3 GitHub 調査
- [ ] `gh search prs` で関連 PR を探す
- [ ] `gh search issues` で関連 issue を探す
- [ ] PR レビューコメントを読む
- [ ] maintainer の stance を整理する
- [ ] author が AMD 社員か外部貢献かを可能な範囲で分類する

### 6.4 見たい問い
- [ ] gfx900 経路は AMD 本流起源か
- [ ] コミュニティ補修が入っているか
- [ ] 削除提案があったか
- [ ] 明示的な legacy support 意図があったか
- [ ] 「残置」なのか「積極維持」なのか

### 成果物
- [ ] `provenance_map.md`
- [ ] `gfx900_history_timeline.md`
- [ ] `support_intent_notes.md`
- [ ] `community_vs_vendor_matrix.md`

---

## 7. 境界層調査

### 7.1 コミュニティが握れる層の整理
- [ ] userspace library の保守可能性を整理する
- [ ] solver registry の保守可能性を整理する
- [ ] fallback logic の保守可能性を整理する
- [ ] capability table の保守可能性を整理する
- [ ] build system / CI の保守可能性を整理する

### 7.2 コミュニティが握りにくい層の整理
- [ ] カーネルモードドライバ境界を整理する
- [ ] firmware / microcode 境界を整理する
- [ ] QA / 製品保証 / リリース判定の境界を整理する

### 7.3 実質サポートとしての整理
- [ ] 「コミュニティにより成立する実質サポート」を定義する
- [ ] 「コミュニティだけでは成立しない部分」を定義する
- [ ] 境界を越えるために必要な条件を整理する

### 成果物
- [ ] `support_boundary.md`
- [ ] `community_maintainable_layers.md`
- [ ] `non_community_layers.md`

---

## 8. 含意層整理

### 8.1 将来シナリオ
- [ ] 現状の設計で自然に残る層を整理する
- [ ] 消えるならどの層から消えやすいか整理する
- [ ] 再統合の観点から重要な接点を整理する
- [ ] コミュニティが押さえるべき層を整理する

### 8.2 仮説評価
- [ ] gfx900 生存は偶然か副産物かを評価する
- [ ] 抽象化の筋が再統合に有利かを評価する
- [ ] 「表のサポート」と「本当の意味でのサポート」の違いを文章化する

### 8.3 まとめ
- [ ] 研究仮説の最終版を作る
- [ ] 観測 / 解釈 / 留保 を分けて書く
- [ ] 反証可能な形で結論を書く

### 成果物
- [ ] `future_support_paths.md`
- [ ] `natural_maintenance_scenarios.md`
- [ ] `what_can_be_extended.md`
- [ ] `what_cannot_be_extended.md`
- [ ] `final_hypothesis.md`

---

## 9. 最終的に答える問い

- [ ] Vega / gfx900 はなぜ今も生きているのか
- [ ] ROCm は何をどうサポートしているのか
- [ ] 「サポート終了」とは何を意味するのか
- [ ] コミュニティはどこまで実質サポートを成立させられるか
- [ ] 将来の再統合 / 共通化に対して、現構造は何を意味するか

---

## 10. 優先度つき着手順

### 最優先
- [ ] 既存観測の canonical 化
- [ ] `gfx900` / `fallback` / `dot4` / `IsApplicable` の静的経路整理
- [ ] 実機での solver 選択確認
- [ ] HSACO 逆アセンブルで命令確認

### 次点
- [ ] クラス構造 / 責務分離の可視化
- [ ] `git blame` / PR / issue による provenance 調査
- [ ] コミュニティ保守可能範囲の明確化

### その次
- [ ] 将来シナリオ整理
- [ ] 再統合仮説の評価
- [ ] 最終まとめ文書の作成