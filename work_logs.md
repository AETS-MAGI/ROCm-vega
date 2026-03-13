# Vega/gfx900 調査 ワークログ

更新日: 2026-03-13
対象: `/home/limonene/ROCm-project/tank/lab_notebook/notes/vega_investigations/`

このログは「何をやったか・何を見たか・何がわかったか」を時系列で記録する。
推論・仮説は `tmp/hypothesis.md`、確定した事実は `facts.md` に分離している。
ここは「作業の流れ」を残す場所。

---

## Phase 1 | 静的コード調査（MIOpen / rocBLAS / CK / Tensile）

### [完了] MIOpen: gfx900 関連 solver 経路の全件確認

**何をやったか**

`docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo` 配下の
MIOpen ソースを直接開いて、gfx900 の filter 条件を全件追った。

**主な確認先ファイル（行番号付き）**

| ファイル | 行 | 内容 |
|---|---:|---|
| `conv_mlir_igemm_fwd.cpp` | 188 | `StartsWith(device_name, "gfx900") return false` |
| `conv_mlir_igemm_bwd.cpp` | 68  | 同上 BWD |
| `conv_mlir_igemm_wrw.cpp` | 69  | 同上 WRW |
| `conv_asm_implicit_gemm_v4r1_dynamic.cpp` | 293, 343 | gfx900/gfx906 を明示許可 |
| `conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp` | 142 | 同上 |
| `conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp` | 306 | 同上 |
| `implicitgemm_util.hpp` | 101-105 | `IsXdlopsSupport`: gfx900 は false |
| `implicitgemm_util.hpp` | 95 | `MIOPEN_DEBUG_CONV_IMPLICIT_GEMM_XDLOPS_EMULATE` |
| `conv_winoRxS.cpp` | 210 | gfx900/gfx906 Winograd v21 優先分岐 |
| `conv_MP_bidirectional_winograd.cpp` | 202, 210 | gfx900/gfx906/gfx908 限定 |
| `conv_bin_wino3x3U.cpp` | 61 | Binary Winograd gfx900 条件 |
| `find_solution.hpp` | 326, 381, 451 | `IsApplicable` 共通フィルタ |
| `problem.cpp` | 573, 575, 625, 627 | "Not applicable" ログ出力点 |
| `solver_finders.cpp` | 98, 109-110 | ImplicitGEMM finder 入り口 |
| `solver.cpp` | 508-510, 546, 569 | MLIR/DLOPS の solver 登録 |

**わかったこと**

- MIOpen は「候補列挙 + `IsApplicable` フィルタ」方式（if-else フォールバックチェーンではない）
- gfx900 では MLIR iGEMM（FWD/BWD/WRW）が除外 → ASM v4r1 dynamic / DLOPS / Winograd へ流れる設計
- XDLops 系は共通ガードで gfx900 を弾く（`IsXdlopsSupport` が false）
- Winograd / 旧ASM にも gfx900 明示条件が残っている

---

### [完了] rocBLAS / Tensile: gfx900 生存証跡確認

**主な確認先ファイル**

| ファイル | 行 | 内容 |
|---|---:|---|
| `rocblas/library/src/tensile_host.cpp` | 232, 238, 240 | `getLazyLoadingArch` で `gfx900→LazyLoadingInit::gfx900` |
| `rocblas/library/src/tensile_host.cpp` | 1232 | "hipBlasLT failed, falling back to tensile." |
| `rocblas/library/src/tensile_host.cpp` | 1161 | "No Tensile solution found for XF32, fall back to FP32" |
| `rocblas/CMakeLists.txt` | 80-85 | TARGET_LIST_ROCM_5.6〜7.1 に gfx900 継続 |
| `hipblaslt/.../tensile_host.cpp` | 1932, 1944, 1946, 2239 | hipBLASLt 内部でも gfx900 LazyLoading 経路 |
| `miopen/src/gemm_v2.cpp` | 245, 640, 684, 687 | GEMM backend 切替（hipBLASLt/rocBLAS） |

**わかったこと**

- rocBLAS は「hipBLASLt → Tensile」「XF32 → FP32」の二段フォールバックを明示実装
- Tensile/lazy catalog に `gfx900` 向けエントリが設計概念として存在（`TensileLibrary_lazy_gfx900.yaml`, `fallback_gfx900.hsaco`）
- hipBLASLt 内部にも gfx900 LazyLoading 経路あり

---

### [完了] CK / Tensile: dot4 非対応時フォールバック確認

**主な確認先ファイル**

| ファイル | 行 | 内容 |
|---|---:|---|
| `composablekernel/include/ck/utility/inner_product.hpp` | 179-201 | dot4 有無で積和実装が分岐 |
| `Tensile/AsmCaps.py` | 128, 155, 158, 159 | ISA(9,0,0) で `v_dot4*` が False |
| `Tensile/Code.py` | 628, 635 | `int8 not implemented yet for gfx900` コメント |
| `legacy_composable_kernel/.../config.hpp` | 50-90 | gfx900 は `CK_USE_AMD_V_MAC_F32`、dot4/xdlops マクロ無効 |

**わかったこと**

- dot4 ability が立たない世代（gfx900 含む）向けの逐次積和フォールバックが正式実装されている
- これは gfx900 専用ではなく「capability-based な汎用実装」であり、設計の寛容性の証拠

---

### [完了] target_properties / IsMlirSupportedHardware の確認

**主な確認先**

| ファイル | 行 | 内容 |
|---|---:|---|
| `miopen/src/target_properties.cpp` | 51-52 | `"Vega10"→"gfx900"`, `"gfx901"→"gfx900"` |
| `conv_mlir_igemm_fwd.cpp` | 付近 | `IsMlirSupportedHardware()` に gfx900 は含まれる（除外は別条件） |

**わかったこと**

- `IsMlirSupportedHardware` リストに gfx900 は入っている（MLIR対応ハードとして表明）
- にもかかわらず `ConvMlirIgemmFwd::IsApplicable()` が gfx900 を後段で除外
- 「MLIR 対応と表明しつつ個別 arch で例外除外」という二重構造が存在

---

## Phase 2 | 動的実機検証（Vega64 / gfx900）

### [完了] 基本環境確認

- GPU: AMD Radeon RX Vega 64 (`gfx900`)
- OS: EndeavourOS (Linux)
- Route: `/opt/rocm` の標準インストール環境を使用

---

### [完了] solver 強制実行グリッド

**実行したケース**（`miopen-driver conv -S <solver>` による強制指定）

| 強制 solver | 結果 | エラーメッセージ |
|---|---|---|
| `ConvMlirIgemmFwd` | 失敗 | `miirLowerTuningParams MIIR_INVALID_PARAM` / `rc=0x7` |
| `ConvCkIgemmFwdV6r1DlopsNchw` | 不成立 | `not applicable to the current problem` / `rc=0x3` |
| `ConvHipImplicitGemmForwardV4R5Xdlops` | 失敗 | xdlops kernel compile 失敗 (`intrin_mfma_*`, `gcnasm_mfma_*`) / `Code object build failed` → `rc=0x7` |
| `ConvHipImplicitGemmFwdXdlops` | abort | `std::vector::operator[]` assertion / `EXIT=134` |
| `ConvHipImplicitGemmGroupFwdXdlops` (g=2) | 不成立 | `not applicable` / `rc=0x3` |
| `ConvAsmImplicitGemmV4R1DynamicFwd_1x1` | 部分到達 | `CompileSolution` まで進んだが GPU memory access fault |

**DLOPS 追加グリッド（`ConvCkIgemmFwdV6r1DlopsNchw` 全15ケース以上）**

- NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2, C/K=64/128/256, stride=1/2, `-s 1` 有効化
- **全件 `not applicable (rc=0x3)`**
- 含意: DLOPS 系は「候補として登録されている」と「その問題で成立する」は別問題

**dtype 差分テスト（3x3, NCHW, n=16, c=64, k=64, 自然選択）**

| dtype | 選択 solver |
|---|---|
| FP16 | `ConvOclDirectFwd` |
| BFP16 | `GemmFwdRest` |
| FP32 | `ConvBinWinograd3x3U` / `ConvAsm1x1U` / `ConvHipImplicitGemmV4R1Fwd` 等 |

**FP32 自然選択（`fallback_confirmed` 相当）**

以下のsolver が自然選択で成功している（`runtime_verified`）:
- `ConvBinWinograd3x3U`
- `ConvAsm1x1U`
- `ConvHipImplicitGemmV4R1Fwd` (= ASM implicit GEMM v4r1 系)

**ログ保存先**: `~/vega_path_check_logs/` 配下の各 `<CASE_ID>.log`

---

### [完了] solver 失敗モードの3分類確立

| 分類 | rc | 症状 | 意味 |
|---|---|---|---|
| applicability reject | `0x3` / `rc=3` | `not applicable to the current problem` | IsApplicable が false |
| build 失敗 | `0x7` / `rc=7` | `MIIR_INVALID_PARAM` / `Code object build failed` | コンパイル/ライブラリ失敗 |
| runtime abort | `EXIT=134` | `std::vector::operator[]` assertion | 到達したが内部 abort |

---

## Phase 3 | rocMLIR 静的解析 + 接続点調査

### [完了] MIOpen → rocMLIR 境界の特定

**確認先**

| ファイル | 行 | 内容 |
|---|---:|---|
| `miopen/src/mlir_build.cpp` | - | `check_miir_error()` が `MIIR_INVALID_PARAM` を例外化 |
| `miopen/src/hipoc/hipoc_program.cpp` | - | `.mlir` 拡張子分岐 → `BuildCodeObjectInMemory` → `binary.empty()` で throw |
| `rocmlir-lib.cpp` | - | `miirCreateHandle` が失敗時に `nullptr` を返す設計 |
| `fin_interface.cpp` | - | solver id: 98=FWD / 99=BWD / 100=WRW / 80=V4R5Xdlops / 114=DLOPS / 128=FwdXdlops |

**代表失敗ポイント（推定）**: `parseConvConfig`, `isApplicable`, `RockEnabled`, 以降 lower/gen 経路

**成果物**: `trace_map_static.md` に MIOpen→rocMLIR 静的結線を固定

---

### [完了] LD_PRELOAD フック試行（失敗記録）

**やったこと**

- `tools/miir_preload_trace.c` を作成し、MIIR C API フックを試みた
- `run_vega_path_case_miir_trace.sh` で実行

**結果**

- `MIIR_INVALID_PARAM` は再現
- 期待した `[MIIR_TRACE]` ログが出ない
- 調査: `libMIOpen.so` には `miopen::Miir*` ラッパは `GLOBAL DEFAULT` にあるが、`miir*` C API シンボルが見えない

**結論**: 現行 LD_PRELOAD 方式では MIIR 呼び出しを捕捉できない。
別手段（debug ビルド、ソース追加ログ）が必要。

---

## Phase 4 | debug ビルド試行（rocMLIR + MIOpen）

### [完了（部分）] MIOpen debug ビルド

**作成した補助スクリプト**

- `tools/build_miopen_debug_local.sh`（`ROCMLIR_PREFIX` / `rocMLIR_DIR` を受け取れるよう設計）
- `tools/run_case_with_local_miopen.sh`（ローカル prefix 向け差し替え実行）
- `miopen_debug_rebuild_plan.md`（手順書）

**失敗経緯とその対処**

| ステップ | 結果 | 対処 |
|---|---|---|
| 初回 configure | `nlohmann_json` 不足 | `nlohmann-json` 導入 |
| 再 configure | `Could NOT find rocMLIR` / `Could not find libMLIRMIOpen` | rocMLIR を先に local install する必要と判明 |
| → rocMLIR build が前提と確定 | - | - |

**現状**: rocMLIR install 待ちで停止。`rocMLIRConfig.cmake` 未生成。

---

### [完了（部分）] rocMLIR ビルド試行

**建てたビルドディレクトリ群**

```
tmp/rocmlir-build-*          # build ディレクトリ（複数試行）
tmp/rocmlir-prefix-*         # install prefix（複数試行）
tmp/rocmlir_build_*.log      # ビルドログ
```

**試行経緯**

| 試行 | generator | 結果 |
|---|---|---|
| 初回 | なし（cmake デフォルト） | `Ninja` 未導入で失敗 |
| 再試行 | `Unix Makefiles` | `pybind11` 不足で失敗 |
| 再々試行 | `Unix Makefiles` | configure は通るが長時間化・割り込み終了 (`EXIT:130`) |
| detached 起動 | `Unix Makefiles` | 割り込み耐性を `nohup` で確保。ただし Makefiles だと configure フェーズが極端に遅い |
| 最終 detached 起動 | `Ninja`（導入後） | `start_rocmlir_build_detached.sh` で起動。完走確認は未完。 |

**依存追加対応**

- `pybind11`: `sudo pacman -S pybind11` → configure で `Found pybind11` を確認

**現状**: detached Ninja ビルドの完走が未確認。`rocMLIRConfig.cmake` の生成を確認できれば MIOpen debug ビルドに繋げられる。

---

## Phase 5 | git blame / provenance 調査

### [完了] MIOpen MLIR iGEMM gfx900 除外の根拠コミット特定

**やったこと**

```bash
cd <ROCm_AMD_Repo>
git blame rocm-libraries/projects/miopen/src/solver/conv/conv_mlir_igemm_fwd.cpp -L 180,200
git show 2407d2f556c7635de3f4b3f009681bdd92ba82e2
git show b0f912e5244b -- conv_mlir_igemm_bwd.cpp conv_mlir_igemm_wrw.cpp
git show 2407d2f -- conv_mlir_igemm_bwd.cpp conv_mlir_igemm_wrw.cpp
```

**確定した結果**

| 属性 | 値 |
|---|---|
| 除外コミット | `2407d2f556c7635de3f4b3f009681bdd92ba82e2` |
| 作者 | Zhuoran Yin (`zhuoryin@amd.com`, AMD 社員) |
| 日付 | 2021-12-22 |
| コミットメッセージ | `[MLIR] Disable gfx900 from non-xdlops solver (#1328)` |
| 対象 | FWD / BWD / WRW 全3ファイルを同一コミットで一括除外 |
| 参照 issue | `https://github.com/ROCmSoftwarePlatform/llvm-project-private/issues/389` |

**URL 修正コミット**

| 属性 | 値 |
|---|---|
| コミット | `b0f912e5244b` |
| 作者 | Artem Tamazov |
| 日付 | 2023-12-13 |
| 内容 | `ROCmSoftwarePlatform` → `ROCm` 組織名変更のみ（実質内容の変更なし） |

**重要な判明事項**

- `#389` は AMD 社内の**非公開** LLVM リポジトリ（`llvm-project-private`）の issue
- 公開リポジトリ `ROCm/MIOpen #389`・`ROCm/rocMLIR #389` とは**全くの別物**（これを確認するまで空振り探索が続いていた）
- 除外は AMD 社員による意図的コミットであり、コミュニティパッチではない
- 問題根拠は LLVM/コンパイラバックエンド（AMDGPU codegen）側の制約を示唆（MIOpen/rocMLIR 本体の問題ではない）

**未確認の後続アクション**

- MIOpen PR #1328 のレビューコメントを GitHub で確認（追加背景情報の可能性）
- 公開 `llvm-project` での gfx900 / MLIR 関連コミット・issue 照合

---

### [未完了] #389 の内容推定

private issue のため本文は外部から読めない。
ただし以下の間接証拠から、内容を推測している:

- `MIIR_INVALID_PARAM` が `miirLowerTuningParams` で発生（実機確認済み）
- `Disable` という語は `Remove` より「一時的/バグ回避的な無効化」のニュアンスが強い
- 参照元が `llvm-project-private` = LLVM コンパイラレベルの issue である可能性が高い

断定不可。「設計判断」か「既知バグ回避」かは未確定。

---

## 作成した成果物ファイル一覧

### ドキュメント

| ファイル | 状態 | 内容 |
|---|---|---|
| `vega-rocm.md` | 継続更新 | 主推論経路調査本体（真実源） |
| `facts.md` | 継続更新 | 確定した事実（code/runtime_verified 分類） |
| `tmp/hypothesis.md` | 継続更新 | 仮説・解釈・検証進捗 |
| `TODO.md` | 継続更新 | タスクリスト |
| `trace_map_static.md` | 第1版完了 | 静的結線（solver登録→IsApplicable→MLIR境界） |
| `trace_map_dynamic.md` | 第1版完了 | 動的失敗シグネチャ対応表 |
| `solver_observation_log.md` | 継続追記 | 実機 solver 選択ログ集積 |
| `hsaco_disassembly_notes.md` | 第1版完了 | HSACO 逆アセンブル手順・dot4 命令確認手順 |
| `miir_runtime_trace.md` | 完了（行き止まり） | LD_PRELOAD 試行記録 |
| `miopen_debug_rebuild_plan.md` | 参照用 | MIOpen debug ビルド手順書 |
| `rocmlir_integration_proposal.md` | 参照用 | rocMLIR 調査フェーズ提案 |
| `disassemble_rocm.md` | 参照用 | 逆アセンブル手順 |
| `investigation_plan.md` | 参照用 | 調査計画 6層構造・仮説A〜E |
| `dlops_grid_results_20260313.md` | 結果固定 | DLOPS グリッド探索結果 |

### スクリプト

| ファイル | 内容 |
|---|---|
| `run_vega_path_case.sh` | 1ケース実行・ログ保存・抽出の半自動スクリプト |
| `run_vega_path_case_miir_trace.sh` | MIIR トレース付き実行スクリプト |
| `sync_vega-logs.sh` | ログ同期スクリプト |
| `tools/build_miopen_debug_local.sh` | MIOpen debug ビルドスクリプト |
| `tools/build_rocmlir_local.sh` | rocMLIR ビルドスクリプト |
| `tools/start_rocmlir_build_detached.sh` | rocMLIR nohup 起動スクリプト |
| `tools/run_case_with_local_miopen.sh` | ローカル MIOpen 差し替え実行 |
| `tools/miir_preload_trace.c` | LD_PRELOAD フックソース（現行方式では不成立） |

---

## 現在のブロッカーと未解決事項

| 項目 | 状態 | 備考 |
|---|---|---|
| rocMLIR Ninja ビルド完走 | 未確認 | detached 起動後の確認が必要 |
| MIOpen debug ビルド | 停止中 | `rocMLIRConfig.cmake` 待ち |
| `miirCreateHandle` の nullptr 分岐確定 | 未達成 | debug ビルド成功後に再実行 |
| INT8 非 naive solver 自然選択 | 未達成 | 全形状で `ConvDirectNaiveConvFwd` のみ選択中 |
| MIOpen PR #1328 レビューコメント確認 | 未着手 | git blame 完了後の次ステップ |
| 公開 llvm-project での gfx900 MLIR 痕跡探索 | 未着手 | private #389 の外部相関探索 |

---

## 「やらないと決めたこと」メモ

| 内容 | 理由 |
|---|---|
| LD_PRELOAD での MIIR C API フック | `miir*` C シンボルが `libMIOpen.so` から直接見えないため不成立 |
| `find` / 広範囲 Glob での全ファイル探索 | タイムアウト頻発。直接パス指定・`ls` 段階アプローチに切り替え |
| MIOpen フォークによる MLIR gfx900 対応 | LLVM コンパイラレベルの問題のため MIOpen 側だけでは修正不可 |
