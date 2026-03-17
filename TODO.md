# ROCm / Vega(gfx900) 調査 TODO

## 「本当の意味でのサポート」を読むための実行タスク一覧

---

## 0. 事前準備

- [x] 調査対象リポジトリ一覧を確定する
  - [x] ROCm
  - [x] HIP
  - [x] ROCr
  - [x] MIOpen
  - [x] rocBLAS
  - [x] Tensile
  - [x] Composable Kernel (CK)
  - [x] retired / legacy repos (`00_legacy-repos`)
    - [x] ROCR-Runtime
    - [x] Tensile
    - [x] MIOpen (metadata only at the moment)
    - [x] ROCm/vllm (supplementary)
- [x] ローカル作業ディレクトリを作成する
- [x] 各リポジトリを clone する
- [x] 調査結果保存用ディレクトリを作る
  - [x] `notes/`
  - [x] `artifacts/`
  - [x] `logs/`
  - [x] `history/`
  - [x] `graphs/`
- [x] 観測分類ルールを決める
  - [x] `code_verified`
  - [x] `runtime_verified`
  - [x] `history_verified`
  - [x] `hint_only`
  - [x] `hypothesis`
  - [x] `out_of_scope`

---

## 1. 既存観測の固定

- [x] 既存メモを canonical な調査メモに統合する
- [x] 既知の主要仮説を一覧化する
- [x] 既知の主要経路を一覧化する
- [x] 既知の未確定事項を一覧化する
- [x] `trace_map_static.md` の初版を作る
- [ ] `knowns_unknowns.md` を作る

### 既知事項として固定したいもの

- [x] gfx900 向け solver / backend 経路の残存
- [x] MLIR iGEMM が gfx900 を明示除外していること
- [x] ASM implicit GEMM 系の生存
- [x] Tensile 側の capability / fallback の存在
- [x] DP4A / dot4 非対応時の代替経路候補

---

## 2. 思想層調査

### 2.1 ROCm 全体思想の把握

- [ ] ROCm 全体のレイヤ構造を整理する
- [ ] ROCr / HIP / MIOpen / rocBLAS / Tensile / CK の責務を一文で定義する
- [ ] 各コンポーネントが「抽象化」「最適化」「互換性」のどれを主に担当するか整理する
- [ ] retired repo から current repo への移行先を表にする
- [ ] repo retirement が build/system consolidation の一部かを検討する

### 2.2 設計思想の観点で見る

- [ ] 世代差吸収が capability ベースか、個別分岐ベースかを確認する
- [ ] 「速い経路」と「広く通る経路」が分離されているか確認する
- [ ] backend 切替が一般化されているか確認する
- [ ] front-end API が hardware-agnostic か確認する
- [ ] fallback が場当たり対応か設計の一部かを判定する

### 思想層調査の成果物

- [ ] `design_philosophy.md`
- [ ] `abstraction_layers.md`
- [ ] `support_model_hypothesis.md`

### 2.3 retired repo archaeology

- [ ] `ROCR-Runtime -> rocm-systems` の移行意味を整理する
- [ ] `Tensile -> rocm-libraries` の移行意味を整理する
- [ ] `ROCm/vllm -> upstream vllm` を ROCm core と分けて位置づける
- [ ] legacy `MIOpen` clone が展開できたら current tree と差分監査する

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

### 構造層調査の成果物

- [ ] `class_map.md`
- [ ] `solver_architecture_map.md`
- [ ] `device_capability_flow.md`
- [ ] `gfx900_related_nodes.md`

---

## 4. 静的経路調査

### 4.1 MIOpen 系

- [x] solver 列挙起点を見つける
- [x] `IsApplicable` の呼び出し連鎖を追う
- [x] gfx900 を通す条件を列挙する
- [x] gfx900 を弾く条件を列挙する
- [x] MLIR iGEMM 系の除外条件をまとめる
- [x] ASM implicit GEMM 系の通過条件をまとめる
- [x] DLOPS / Winograd / legacy solver の条件を整理する

### 4.2 rocBLAS / Tensile 系

- [x] rocBLAS から Tensile に渡る入り口を特定する
- [x] Tensile backend 選択条件を整理する
- [x] lazy loading / fallback code object の条件を整理する
- [x] hipBLASLt → Tensile fallback 条件を整理する
- [x] XF32 → FP32 fallback 条件を整理する

### 4.3 CK 系

- [x] CK 側の architecture / capability 判定を整理する
- [x] legacy CK の扱いを整理する
- [x] dot4 有無に関する分岐を整理する

### 4.4 front-end からの流れ

- [ ] ユーザーが呼ぶ API / 関数を特定する
- [ ] front-end API から solver/backend 選択までの call chain を図にする
- [ ] 「ユーザーに何を隠しているか」を整理する

### 静的経路調査の成果物

- [x] `trace_map_static.md`
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

- [x] `ConvAsmImplicitGemmV4R1Dynamic*` が本当に選ばれるか確認する（FP32 自然選択で `ConvHipImplicitGemmV4R1Fwd` 確認）
- [x] `ConvMlirIgemm*` が実際に落ちるか確認する
- [x] DLOPS 系がどの条件で通るか確認する（全15ケース以上で `not applicable` を確認）
- [x] dot4 非対応時に代替経路へ落ちるか確認する

補足(2026-03-13):

- `-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の強制実行で `CompileSolution` / `ConvolutionForwardImmediate` までは到達したが、GPU memory access fault が発生。自然選択での成立条件確認は未完。
- `-S ConvMlirIgemmFwd` の強制実行で `MIIR_INVALID_PARAM` と `RunForwardGPU() FAILED, rc = 0x7` を確認。
- `-S ConvCkIgemmFwdV6r1DlopsNchw` の強制実行で `not applicable to the current problem` と `RunForwardGPU() FAILED, rc = 0x3` を確認。
- `ConvCkIgemmFwdV6r1DlopsNchw` の強制グリッド7ケース（NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2）でも全件 `not applicable`（rc=0x3）。
- `ConvCkIgemmFwdV6r1DlopsNchw` の強制グリッド8ケース（`-s 1`, C/K=128/256, stride1/2, g=1/2）でも全件 `not applicable`（rc=0x3）。
- `ConvHipImplicitGemmFwdXdlops` 強制実行では `CompileSolution`/`FindSolutionImpl` まで進むが、`std::vector::operator[]` assertion で abort (`EXIT=134`)。
- `ConvHipImplicitGemmForwardV4R5Xdlops` 強制実行では xdlops kernel compile失敗 (`intrin_mfma_*` / `gcnasm_mfma_*` / `FLOAT`) で `Code object build failed` -> `RunForwardGPU() FAILED, rc = 0x7`。
- `ConvHipImplicitGemmGroupFwdXdlops` (`g=2`) 強制実行では `not applicable` -> `RunForwardGPU() FAILED, rc = 0x3`。
- dtype軸同形状（3x3, NCHW, n16/c64/k64）で、FP16は `ConvOclDirectFwd`、BFP16は `GemmFwdRest` に分岐することを確認。
- 同形状3x3で `ConvHipImplicitGemmFwdXdlops` を FP16/BFP16 に強制すると、両者とも assertion abort（`__EXIT_CODE=134`）。
- 同形状3x3で `ConvHipImplicitGemmForwardV4R5Xdlops` を FP16/BFP16 に強制すると、両者とも `Code object build failed` -> `rc=0x7`（`__EXIT_CODE=7`）。

次アクション(2026-03-13):

- [x] `pybind11` 依存を導入（`sudo pacman -S --needed --noconfirm pybind11`）
- [x] rocMLIR configure で `Found pybind11` を確認
- [x] rocMLIR build/install を最後まで完走（直近試行は割り込みで `EXIT:130`） → 回避済み: MLIR=Off で MIOpen ビルド成功。強制実行テストで失敗メカニズム確定済み
- [x] `rocMLIR_DIR` 欠落で MIOpen configure が停止する原因を確認（`Could NOT find rocMLIR`）
- [x] rocMLIR先行ビルド導線を追加 (`tools/build_rocmlir_local.sh`)
- [x] MIOpenビルドに `ROCMLIR_PREFIX` / `rocMLIR_DIR` を渡せるよう更新 (`tools/build_miopen_debug_local.sh`)
- [x] ローカルDebug版MIOpenのビルド手順を固定 (`miopen_debug_rebuild_plan.md`)
- [x] ローカルprefix向けビルドスクリプトを追加 (`tools/build_miopen_debug_local.sh`)
- [x] ローカルMIOpen差し替え実行ラッパーを追加 (`tools/run_case_with_local_miopen.sh`)
- [x] ローカルrocMLIRを install して `rocMLIRConfig.cmake` の生成を確認 → 回避: MLIR=Off でビルド。代わりにシステム MIOpen で強制実行テスト実施
- [x] ローカルDebug版MIOpenで `vega64_int8_force_mlir_fwd` を再実行してログ採取 → システム MIOpen で実施。boost::optional crash を再現
- [ ] `src/mlir_build.cpp` 一時ログパッチで `handle` と `Miir*` 戻り値を採取（MLIR有効ビルドが必要。優先度低）
- [x] `miirCreateHandle` の `nullptr` 分岐を runtime 観測で最終確定 → 代替確認: Perf DB 不在 → boost::optional crash の経路で確定

  補足(2026-03-13, WD-Black再試行):

  - [x] WD-Black を `/home/limonene/ROCm-project/WD-Black` にマウントしてビルド先をローカルNVMe化
  - [x] `HALF_INCLUDE_DIR-NOTFOUND` を回避（`HALF_INCLUDE_DIR=/usr/include`）
  - [x] configure 停滞（`git describe`）を回避（`-DGIT=/bin/false -DGit_EXECUTABLE=/bin/false`）
  - [x] `frugally-deep` 必須エラーを回避（`MIOPEN_ENABLE_AI_*` をOff）
  - [x] `tmp/miopen_debug_build_20260313_215209_wdblack.log` の完走確認 → WD-Black 上で別ビルド（20260314_135541）が成功

### 5.5 MIOpen debug ビルド + MLIR 強制実行テスト（2026-03-14 完了）

- [x] WD-Black NVMe にソース clone（CIFS 回避）
- [x] MIOpen debug build 成功（MLIR=Off, CK=Off, AI=Off 構成）
- [x] FP32 conv 基本動作確認（ローカル MIOpenDriver）
- [x] MLIR iGEMM 強制実行テスト INT8（boost::optional crash 再現）
- [x] MLIR iGEMM 強制実行テスト FP32（同上）
- [x] 二重排除メカニズム（IsMlirSupportedHardware vs IsApplicable）をソースコードで確定
- [x] Perf DB に gfx900 用 tuning パラメータ不在を確認

### 動的トレース調査の成果物

- [x] `trace_map_dynamic.md`
- [x] `solver_observation_log.md`
- [x] `hsaco_disassembly_notes.md`
- [ ] `gfx900_vs_other_gpu_diff.md`

---

## 6. 履歴層調査

### 6.1 blame / commit 調査

- [x] `conv_mlir_igemm_fwd.cpp` の gfx900 除外行の `git blame` を実施
  - 結果: コミット `2407d2f`（Zhuoran Yin, AMD, 2021-12-22, PR #1328）
  - 参照 issue: `llvm-project-private/issues/389`（AMD 社内非公開）
- [x] `conv_mlir_igemm_bwd.cpp` / `conv_mlir_igemm_wrw.cpp` の除外行確認
  - 結果: 全3ファイルが同一コミットで一括除外
- [x] `gfx900` 関連行の `git blame` を追加実施（MLIR 以外の箇所）
  - ASM v4r1 dynamic: PR #166 (carlushuang, 2020) で導入。gfx900/gfx906 専用設計
  - Winograd: 初期 MIOpen 時代から。FP32 で gfx900 明示許可
- [x] ASM v4r1 dynamic の gfx900/gfx906 許可行の `git blame`
  - PR #166 (Fwd), #272 (Bwd), Bug fix #1001 (Wrw, 2021)
- [x] Winograd / 旧 ASM の gfx900 条件行の `git blame`
  - 6 ファイルで gfx900 許可確認。FP16 は gfx906+、FP32 は gfx900 通過
- [x] `dot4` / `dp4a` 関連行の `git blame`
  - MIOpen 内に dot4/dp4a 直接参照なし（Tensile/CK 側の概念）
- [x] `IsApplicable` 重要箇所の `git blame`（主要 solver）
  - GTC 系: 全て gfx908+ only. v4r1: gfx900/gfx906 only. Winograd: gfx803~gfx908

### 6.2 commit 意図調査

- [x] コミット `2407d2f` の diff を確認
  - 意図分類: **バグ回避（疑い）** / 設計判断（確定不可）
  - 動詞 `Disable`（= `Remove` / `Drop` より一時的ニュアンス）
  - 参照先が private であるため true reason は外部確認不可
- [x] 他の gfx900 関連コミットの diff を読む
  - PR #166 (v4r1 追加), #272 (bwd 追加), #1001 (wrw バグ修正), #1328 (MLIR disable)
  - Tensile: #1595 (gfx900:xnack- 追加, 外部), #1862 (fallback library, 外部)
- [x] commit を意図別に分類する
  - [x] 互換維持: Tensile #1595 (gfx900:xnack- accept)
  - [x] fallback 追加: Tensile #1862 (lazy loading fallback)
  - [x] 最適化追加: PR #166, #272 (v4r1 dynamic)
  - [x] バグ修正: PR #1001 (vega wrw validation fail)
  - [x] ビルド修正: N/A
  - [x] 削除 / 切り離し: PR #1328 (MLIR gfx900 disable)
  - [x] 不明: N/A

### 6.3 GitHub 調査

#### 最優先

- [x] **MIOpen PR #1328 のレビューコメントを確認**（`ROCm/MIOpen/pull/1328`）
  - 目的: private #389 に替わる追加背景情報の取得
  - コマンド: `gh pr view 1328 --repo ROCm/MIOpen --comments`
- [x] 公開 `llvm-project` で gfx900 / MLIR 関連 commit・issue を再探索
  - 目的: private #389 と同系統の痕跡が外部に残っていないか確認
  - コマンド: `gh search issues --repo llvm/llvm-project "gfx900 MLIR" --state open|closed`
  - 結果: 直接相関する公開issueは未発見（2026-03-15 時点）

#### GitHub 調査の次点

- [ ] `MiirIsConfigApplicable` の内部チェックを掘る（MLIR ライブラリ側の直接制限）
- [x] `gh search prs` で gfx900 関連 PR を探す（MIOpen / rocBLAS / Tensile）
  - MIOpen: 25+ PR (v4r1 追加/修正, Winograd, MLIR disable)
  - Tensile: 51 PR (gfx900:xnack- 追加, fallback library, etc.)
  - rocBLAS: 44 PR (logic files, known_bugs, architecture splits)
  - CK: 0件 (xdlops 前提のため gfx900 は対象外)
- [x] PR レビューコメントを読む（主要な gfx900 生存経路の変更点）
  - PR #1328: ROCm 5.1 マイルストーン。テストインフラ分離を含む計画的切り離し
- [x] maintainer の stance を整理する
  - AMD: MLIR disable、GTC は gfx908+ 専用。古い solver は放置（積極維持ではない）
  - 外部: Tensile fallback / gfx900:xnack- を補修
- [x] author が AMD 社員か外部貢献かを可能な範囲で分類する（MLIR 除外以外も）
  - ASM v4r1: carlushuang, shaojiewang (CONTRIBUTOR — AMD 関連の可能性高)
  - MLIR disable: jerryyin (MEMBER — AMD 社員確定)
  - Tensile fallback: cgmb, GZGavinZhao (CONTRIBUTOR — 外部)

### 6.4 見たい問い

- [x] gfx900 MLIR 除外は AMD 本流起源か → **Yes（AMD 社員 Zhuoran Yin）**
- [x] 他の gfx900 生存経路（ASM v4r1 dynamic 等）の出所確認
  - v4r1: AMD contributor (2020), Winograd: 初期MIOpen, Tensile: 外部 contributor (2022-2024)
- [x] コミュニティ補修が入っているか
  - **Yes**: Tensile #1595, #1862 は明確に外部コントリビュータ
- [ ] 削除提案があったか
- [x] 明示的な legacy support 意図があったか
  - Tensile #1595 の PR 本文: 「AMD公式バイナリには関係ないが、ソースビルドユーザーに有用」
- [x] 「残置」なのか「積極維持」なのか
  - ASM v4r1/Winograd: 残置（AMD による最近の保守は 2023 Winograd perf W/A が最後）
  - Tensile fallback: コミュニティによる積極補修

### 履歴層調査の成果物

- [x] `provenance_map.md`
- [ ] `gfx900_history_timeline.md`
- [ ] `support_intent_notes.md`
- [ ] `community_vs_vendor_matrix.md`

---

## 7. 境界層調査

### 7.1 コミュニティが握れる層の整理

- [x] userspace library の保守可能性を整理する → `support_boundary.md` §2
- [x] solver registry の保守可能性を整理する → `support_boundary.md` §2
- [x] fallback logic の保守可能性を整理する → `support_boundary.md` §2
- [x] capability table の保守可能性を整理する → `support_boundary.md` §2
- [x] build system / CI の保守可能性を整理する → `support_boundary.md` §2b

### 7.2 コミュニティが握りにくい層の整理

- [x] カーネルモードドライバ境界を整理する → `support_boundary.md` §2
- [x] firmware / microcode 境界を整理する → `support_boundary.md` §2 + P8 shipped artifacts
- [x] QA / 製品保証 / リリース判定の境界を整理する → `support_boundary.md` §2c

### 7.3 実質サポートとしての整理

- [x] 「コミュニティにより成立する実質サポート」を定義する → `support_boundary.md` §3
- [x] 「コミュニティだけでは成立しない部分」を定義する → `support_boundary.md` §2-3
- [x] 境界を越えるために必要な条件を整理する → `support_boundary.md` §4

### 7.4 出荷成果物調査（2026-03-15 追加）

- [x] MIOpen Perf DB のアーキテクチャ別行数を実測
- [x] rocBLAS プリコンパイル済みファイルのアーキテクチャ別比較
- [x] firmware blob の確認
- [x] 3層モデル→4層モデルへの拡張（配布層追加）
- [x] facts.md / hypothesis.md / provenance_map.md への反映
- [x] HTML 同期（solver-trace / reveal-hypothesis / rocm-history / presentation）

### 境界層調査の成果物

- [x] `support_boundary.md`
- [x] `community_maintainable_layers.md` → `support_boundary.md` §2.1 に統合
- [x] `non_community_layers.md` → `support_boundary.md` §2.2 + §2c に統合

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

### 含意層整理の成果物

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

### [完了済み（コード調査）]

- [x] 既存観測の canonical 化（`vega-rocm.md` が真実源）
- [x] `gfx900` / `fallback` / `dot4` / `IsApplicable` の静的経路整理（`trace_map_static.md`）
- [x] 実機での solver 選択確認（FP32 `fallback_confirmed` 取得）
- [x] HSACO 逆アセンブルで命令確認（`hsaco_disassembly_notes.md`）
- [x] git blame: MLIR iGEMM gfx900 除外コミット `2407d2f` 確定

### 最優先（まず動く）

1. ~~**MIOpen PR #1328 レビューコメント確認**~~ → **完了**

   - `gh pr view 1328 --repo ROCm/MIOpen --comments`
   - 意義: private issue `#389` の内容を外部から最も手早く類推できる手段
   - 工数: 低（コマンド1本 + 読むだけ）

1. ~~**INT8 非 naive solver 自然選択の確認**~~ → **探索完了（未達成を確定）**

   - 2026-03-15 追加6ケース（`-s 1`）でも全件 `ConvDirectNaiveConvFwd`（Solution 85）のみ選択。
   - 現時点では「非 naive が出ない」という結論が `runtime_verified`。
   - 追加探索を続ける場合は NCHW 以外の layout 制約・別実装ブランチを前提に再設計が必要。

1. ~~**rocMLIR Ninja ビルド完走 → `miirCreateHandle` nullptr 分岐確定**~~ → **解決済み**

   - MLIR=Off で MIOpen debug ビルド成功。システム MIOpen での MLIR 強制実行テストで失敗メカニズム（Perf DB 不在 → boost::optional crash）を確定。
   - rocMLIR prefix は消滅していたが、代替手段で目的を達成。

### 優先度つき着手順の次点（2026-03-17 再優先順位）

1. **`design_philosophy.md` + `abstraction_layers.md` を先に作る**

   - 根拠は `ROCm/README.md`, `ROCm/docs/what-is-rocm.rst`, `TheRock/README.md`,
     `TheRock/cmake/therock_subproject.cmake`, `TheRock/cmake/therock_amdgpu_targets.cmake`,
     `rocm-systems/README.md` を主とする
   - 意義: 既存の 4層モデル（維持 / 管理 / 補充 / 配布）に対して、
     ROCm 全体の build / integration / component topology 側の一次根拠を固定する
   - 工数: 中

1. **`fallback_chain_map.md` + `gfx900_related_nodes.md` を作る**

   - 既存の `trace_map_static.md`, `trace_map_dynamic.md`, `support_boundary.md`,
     `provenance_map.md`, `facts.md` の内容を cross-component で再配置する
   - MIOpen / rocBLAS / Tensile / CK / TheRock の `GPU_TARGETS` / fallback / gating を
     一枚の地図にする
   - 意義: 追加ログなしで「なぜ gfx900 が半分死に半分生きるか」の構造を最短で可視化できる

1. **`final_hypothesis.md` を早期に書き始める（Phase 8-9 を同時消化）**

   - 現状の `facts.md`, `hypothesis.md`, `reveal_hypothesis.md`, `support_boundary.md`,
     `provenance_map.md` を材料に、まず「今すぐ書ける範囲」を試す
   - 不足が見えた箇所だけを次段で補う
   - 意義: 「書くための書き物を増やす」ことを避け、最終問いに必要な穴だけを露出させる

1. **`community_vs_vendor_matrix.md` + `gfx900_history_timeline.md` を中優先度で補完**

   - `provenance_map.md` と `rocm-github-investigate.md` の橋渡しとして使う
   - 意義: 投入主体 / 維持主体 / 運用主体 / 修正可能主体の時間差を明確にする

1. **`provenance_map.md` を拡張**

   - P2/P3 の維持主体、外部修正余地、TheRock 側 `EXCLUDE_TARGET_PROJECTS` との対応を追加
   - 意義: Section 7 と最終結論の接続を強くする

1. **`support_model_hypothesis.md` は必要なら作る**

   - `design_philosophy.md` と `final_hypothesis.md` の間に中間整理が必要な場合のみ着手
   - やらないという選択肢: あり

1. **`class_map.md` / `solver_architecture_map.md` / `device_capability_flow.md` は中優先度で進める**

   - ただし、最初から ROCm 全域の exhaustive な class archaeology はやらない
   - まずは `MIOpen` の convolution 経路に限定し、
     `Handle -> TargetProperties -> ConvolutionContext -> solver registry -> solution`
     の軽量 map を作る
   - 意義: `final_hypothesis.md` の補強と、fallback / gating の責務分離を視覚化する
   - 工数が膨らむ場合は repo-wide 拡張を止め、MIOpen 局所図で打ち切る

1. **Runtime/Systems 層の新規スコープ追加は当面やらない**

   - `HIP -> CLR -> ROCr -> HSA/KFD` は ROCm 全体構造の説明には有益だが、
     今回の中心問い「なぜ gfx900 が生きているか」に対しては周辺的
   - `final_hypothesis.md` で不足が出たときだけ限定的に戻る

1. **`MiirIsConfigApplicable` の内部制約の再確認は optional**

   - private issue #389 の本文は公開側から見えないため、追加で掘る場合も
     public code の境界説明に留める
   - やらないという選択肢: 強くあり

### 参照先（クローン済み ROCm 公式リポジトリ）

- root: `/home/limonene/ROCm-project/WD-Black/ROCm-repos`
- 主要調査対象（現行系）:
  - `MIOpen/src/solver/conv_mlir_igemm_fwd.cpp`
  - `MIOpen/src/solver/conv_ck_igemm_fwd_v6r1_dlops_nchw.cpp`
  - `MIOpen/src/solver/conv_hip_implicit_gemm_fwd_xdlops.cpp`
  - `MIOpen/src/solver/conv_hip_implicit_gemm_fwd_v4r5_xdlops.cpp`
  - `MIOpen/src/hipoc/hipoc_program.cpp` （`Code object build failed`）
  - `MIOpen/src/mlir_build.cpp` （`MIIR_INVALID_PARAM`）
  - `MIOpen/src/convolution_api.cpp` （front-end API -> solution / immediate）
  - `MIOpen/src/include/miopen/conv/context.hpp`
  - `rocBLAS/CMakeLists.txt`
  - `rocBLAS/docs/what-is-rocblas.rst`
  - `Tensile/Tensile/Component.py`
  - `Tensile/docs/src/conceptual/solution-selection-catalogs.rst`
  - `TheRock/cmake/therock_amdgpu_targets.cmake`
  - `TheRock/cmake/therock_subproject.cmake`
  - `ROCm/README.md`
  - `ROCm/docs/what-is-rocm.rst`
  - `rocm-systems/README.md`
- 補助参照:
  - `MIOpen/doc/src/find_and_immediate.md`
  - `MIOpen/doc/src/perfdatabase.md`
  - `rocm-systems/projects/hip/docs/how-to/hip_runtime_api.rst`
  - `rocm-systems/projects/hip/docs/understand/programming_model.rst`
- 注記:
  - 現ローカル clone では `rocm-libraries/projects/miopen/` は存在せず、
    MIOpen standalone repo (`WD-Black/ROCm-repos/MIOpen`) を investigation の現行 root として使う
  - `rocm-libraries` worktree は mass-deleted 状態に見えるため、修復されるまで一次根拠には使わない
- 履歴比較用（旧実装）:
  - `00_legacy-repos/MIOpen/src/...`
  - `00_legacy-repos/Tensile/...`
  - `00_legacy-repos/ROCR-Runtime/...`

### その次

1. `future_support_paths.md`
1. `natural_maintenance_scenarios.md`
1. `what_can_be_extended.md`
1. `what_cannot_be_extended.md`

---

## 12. 残タスク（2026-03-15 時点）

構造把握はほぼ完了。以下の3件のみが未着手 / 未完了。

### 優先度: 低

- [ ] **MLIR 有効 Debug build での内部ログ採取**
  - `src/mlir_build.cpp` の一時ログパッチで `handle` / `Miir*` 戻り値を採取する
  - 失敗メカニズム（Perf DB 不在 → boost::optional crash）はすでに runtime_verified のため必須ではない
  - MLIR 有効ビルドが前提（現行 debug build は MLIR=Off）

### 優先度: 中

- [ ] **`provenance_map.md` の拡張**
  - 現行版（2026-03-15 初版）は P1–P7 の骨格を記載済み
  - 次段階: 「誰が残し・運用し・直せるか」の地図をより詳細化する（特に P2/P3 の維持主体と外部修正余地）
  - Section 7（境界層調査）の成果物 `support_boundary.md` / `community_maintainable_layers.md` と統合する可能性あり

- [ ] **`MIIR_BUILD_FAILURE` を出す具体ケースの実機再現**
  - 現在確認済み: `MIIR_INVALID_PARAM`（rc=0x7）、Perf DB 不在 → `boost::optional::get()` assertion crash
  - 次の failure mode: `MIIR_BUILD_FAILURE` を実際に出す入力ケースを設計する
  - `rocmlir-lib.cpp` の `buildKernelPipeline` (BuildMode) が返す条件を静的に先に確認する

---

## 11. rocMLIR 追加フェーズ（提案実行トラック）

- [x] 提案ドキュメント初版を作成する
  - [x] `rocmlir_integration_proposal.md`
- [x] `rocMLIR` 作業ツリーを展開し、読み取り可能状態を確認する
- [x] MIOpen 側の MLIR 接続点を `trace_map_static.md` へ追記する
- [x] solver id 80/114/128 の登録点と実装対応を 1 ページに集約する
- [x] `MIIR_INVALID_PARAM` 最小再現ケースを 1 ケース固定する
- [x] `Code object build failed` の入力ソース生成地点を特定する
- [x] 失敗モード4分類（`rc=0x3` / `rc=0x7` / `MIIR_INVALID_PARAM` / `EXIT=134`）を trace_map ヘッダ化する
- [x] `convGenerator.isApplicable()` の実装位置を特定し、gfx900 の arch gate 条件を列挙する
- [x] `RockEnabled` の layout/dtype gate と動的失敗ケース（`vega64_int8_force_mlir_fwd`）の対応を 1:1 で照合する
- [x] `ConvMlirIgemmFwd::IsApplicable()` の `gfx900` 明示拒否（issue #389 コメント付き）を確認する
- [x] 実ランタイム向け MIIR トレースラッパを作成する
  - [x] `run_vega_path_case_miir_trace.sh`
  - [x] `tools/miir_preload_trace.c`
- [x] `vega64_int8_force_mlir_fwd` でトレース実行し、`[MIIR_TRACE]` が出ないことを確認する
- [x] `miirCreateHandle` 内の `nullptr` 分岐を最終確定する → 代替確認: システム MIOpen での MLIR 強制実行で CompileSolution → GetInvoker → Perf DB 不在 → boost::optional crash の経路を確定（2026-03-14）

補足:

- `rocMLIR` は作業ツリー展開済み（`mlir/tools/rocmlir-lib/{Miir.h, rocmlir-lib.cpp}` を確認）。
- `MIIR_INVALID_PARAM` 最小再現ケースは `vega64_int8_force_mlir_fwd`（`vega_path_check_logs/vega64_int8_force_mlir_fwd.log`）で固定。
- `Code object build failed` は `hipoc_program.cpp` の `BuildCodeObjectInMemory` にて、拡張子分岐後 `binary.empty()` 判定で throw される。
- `ConvMlirIgemmFwd` は通常経路では `gfx900` を `IsApplicable()` で reject するため、`-S 98` 強制実行は未サポート経路の検証になっている。
- 参照ソース（`ROCm_AMD_Repo`）と実行実体（`/opt/rocm`）の差分可能性があるため、`nullptr` 分岐の最終確定はランタイム側の追加トレースで閉じる。
- `LD_PRELOAD` での C API フックでは MIIR 呼び出しを捕捉できなかった（`vega64_int8_force_mlir_fwd_trace.log` に `[MIIR_TRACE]` 行なし）。
- `libMIOpen.so.1.0` には `miopen::Miir*` ラッパが `GLOBAL DEFAULT` で存在するため、次手は `/opt/rocm` 実体への直接計測（再ビルド or 専用デバッグ版）で分岐を取る。
