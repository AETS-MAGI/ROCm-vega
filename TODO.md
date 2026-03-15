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

### 成果物
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

### 成果物
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

### 成果物
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

### 成果物
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
- [ ] `gfx900` 関連行の `git blame` を追加実施（MLIR 以外の箇所）
- [ ] ASM v4r1 dynamic の gfx900/gfx906 許可行の `git blame`
- [ ] Winograd / 旧 ASM の gfx900 条件行の `git blame`
- [ ] `dot4` / `dp4a` 関連行の `git blame`
- [ ] `IsApplicable` 重要箇所の `git blame`（主要 solver）

### 6.2 commit 意図調査

- [x] コミット `2407d2f` の diff を確認
  - 意図分類: **バグ回避（疑い）** / 設計判断（確定不可）
  - 動詞 `Disable`（= `Remove` / `Drop` より一時的ニュアンス）
  - 参照先が private であるため true reason は外部確認不可
- [ ] 他の gfx900 関連コミットの diff を読む
- [ ] commit を意図別に分類する
  - [ ] 互換維持
  - [ ] fallback 追加
  - [ ] 最適化追加
  - [ ] バグ修正
  - [ ] ビルド修正
  - [ ] 削除 / 切り離し
  - [ ] 不明

### 6.3 GitHub 調査

**最優先**

- [x] **MIOpen PR #1328 のレビューコメントを確認**（`ROCm/MIOpen/pull/1328`）
  - 目的: private #389 に替わる追加背景情報の取得
  - コマンド: `gh pr view 1328 --repo ROCm/MIOpen --comments`
- [x] 公開 `llvm-project` で gfx900 / MLIR 関連 commit・issue を再探索
  - 目的: private #389 と同系統の痕跡が外部に残っていないか確認
  - コマンド: `gh search issues --repo llvm/llvm-project "gfx900 MLIR" --state open|closed`
  - 結果: 直接相関する公開issueは未発見（2026-03-15 時点）

**次点**

- [ ] `MiirIsConfigApplicable` の内部チェックを掘る（MLIR ライブラリ側の直接制限）
- [ ] `gh search prs` で gfx900 関連 PR を探す（MIOpen / rocBLAS / Tensile）
- [ ] PR レビューコメントを読む（主要な gfx900 生存経路の変更点）
- [ ] maintainer の stance を整理する
- [ ] author が AMD 社員か外部貢献かを可能な範囲で分類する（MLIR 除外以外も）

### 6.4 見たい問い

- [x] gfx900 MLIR 除外は AMD 本流起源か → **Yes（AMD 社員 Zhuoran Yin）**
- [ ] 他の gfx900 生存経路（ASM v4r1 dynamic 等）の出所確認
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

2. ~~**INT8 非 naive solver 自然選択の確認**~~ → **探索完了（未達成を確定）**
  - 2026-03-15 追加6ケース（`-s 1`）でも全件 `ConvDirectNaiveConvFwd`（Solution 85）のみ選択。
  - 現時点では「非 naive が出ない」という結論が `runtime_verified`。
  - 追加探索を続ける場合は NCHW 以外の layout 制約・別実装ブランチを前提に再設計が必要。

3. ~~**rocMLIR Ninja ビルド完走 → `miirCreateHandle` nullptr 分岐確定**~~ → **解決済み**
   - MLIR=Off で MIOpen debug ビルド成功。システム MIOpen での MLIR 強制実行テストで失敗メカニズム（Perf DB 不在 → boost::optional crash）を確定。
   - rocMLIR prefix は消滅していたが、代替手段で目的を達成。

### 次点

4. ~~**公開 `llvm-project` での gfx900 / MLIR issue 探索**~~ → **実施済み（直接相関なし）**
  - `gh search issues --repo llvm/llvm-project "gfx900 MLIR" --state open`
  - `gh search issues --repo llvm/llvm-project "gfx900 MLIR" --state closed`
   - 意義: private #389 の外部相関を探す

5. **クラス構造 / 責務分離の可視化**（`class_map.md` 等）
   - 意義: 仮説B（capability-based 設計の副産物）の構造的証拠を整理
   - 工数: 高（コード全体を読む必要あり）
   - やらないという選択肢: 強くあり（仮説Bはすでにコードで十分支持されている）

6. **コミュニティ保守可能範囲の明確化**（Section 7）
   - 意義: Phase 7 の成果物。現状は仮説レベルで成立している。

7. **`MiirIsConfigApplicable` の内部制約の再確認**
  - 意義: private issue #389 の本文が非公開のため、公開ソースで最も近い境界を追加検証する。
   - やらないという選択肢: 強くあり（現段階では「設計の自然な副産物として生存」が十分な結論）

### 参照先（クローン済みROCm公式リポジトリ）
- root: `/home/limonene/ROCm-project/tank/docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo`
- 主要調査対象（現行系）:
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_ck_igemm_fwd_v6r1_dlops_nchw.cpp`
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_xdlops.cpp`
  - `rocm-libraries/projects/miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_v4r5_xdlops.cpp`
  - `rocm-libraries/projects/miopen/src/hipoc/hipoc_program.cpp` （`Code object build failed`）
  - `rocm-libraries/projects/miopen/src/mlir_build.cpp` （`MIIR_INVALID_PARAM`）
  - `rocm-libraries/projects/miopen/src/fin/fin_interface.cpp` （solver id 80/114/128）
  - `rocm-libraries/projects/miopen/src/include/miopen/conv/solvers.hpp`
- 補助参照:
  - `rocm-libraries/projects/miopen/docs/reference/env_variables.rst`
  - `rocm-libraries/projects/miopen/docs/how-to/debug-log.rst`
- 履歴比較用（旧実装）:
  - `00_DEPRECATED/MIOpen/src/...`（同名solver実装・旧registry・旧test）

### その次

7. 将来シナリオ整理
8. 再統合仮説の評価
9. 最終まとめ文書の作成

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
