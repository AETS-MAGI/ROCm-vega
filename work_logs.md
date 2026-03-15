# Vega/gfx900 調査 ワークログ

更新日: 2026-03-15
対象: `/home/limonene/ROCm-project/vega-hbmx-investigations/vega_investigations/`

## 現状サマリ

- gfx900 の MLIR iGEMM 除外は、AMD 社員による明示コミット `2407d2f`（2021-12-22）で導入されたことを確認済み。
- `IsMlirSupportedHardware()` には gfx900 が含まれる一方、`ConvMlirIgemmFwd/Bwd/Wrw::IsApplicable()` 側で後段除外される二重構造を確認済み。
- MLIR 強制実行では `boost::optional::get()` assertion crash まで再現し、MLIR 経路が gfx900 で実用不能であることを実機で確認済み。
- MIOpen debug build は CIFS を避けて WD-Black NVMe 上で成功し、gfx900 向け最小構成（MLIR/CK/AI機能OFF）のビルド導線を確立済み。
- 2026-03-15 以降、AMD Repository の日常運用正本を WD-Black (`/home/limonene/ROCm-project/WD-Black/ROCm-repos`) に固定し、CIFS 側は取得元として扱う方針に変更。
- WD-Black 起点運用のために `tools/open_wdblack_rocm_shell.sh` と `tools/sync_rocm_repo_to_wdblack.sh` を整備し、日常操作を定型化。
- 旧 `ROCm/CHANGELOG` と current release note 群、MIOpen commit history から、`gfx900` が一括削除ではなく「追加 -> private issue 起因 disable -> 既定 build からの後退 -> legacy/fallback 残存」という層状変遷を辿ったことを整理済み。
- WD-Black 上の local official MIOpen snapshot（shallow な `v2.18.0` 系 snapshot）再照合により、`gfx900` 用 `WORKAROUND_ISSUE_1204`（`sramecc-` misreport workaround）と `gfx900_56 / gfx900_64` の Find-db / immediate mode docs 記述が残ることを確認。
- `00_legacy-repos` を調査対象に追加し、`ROCR-Runtime` / `Tensile` / `ROCm/vllm` の README から retired notice と移行先 (`rocm-systems`, `rocm-libraries`, upstream `vllm`) を確認した。
- `00_legacy-repos/MIOpen` の clone 完了後、`develop_deprecated` HEAD (`06977176a`) が non-shallow であること、退役ブランチ上にも `gfx900` MLIR 除外・`WORKAROUND_ISSUE_1204`・Find-db / immediate mode docs が残ることを確認した。
- GitHub PR 文脈の追跡により、`#1231` は public issue `#1204` で露出した `gfx900:sramecc-:xnack-` target-name 誤報への workaround であり、`#1328` は private issue 依存ながら public 側では ROCm 5.1 向け MLIR release/tuning surface から `gfx900` を外す整理として提出されていたことを確認した。
- 現時点の主な未解決事項は、`MiirIsConfigApplicable` を含む MLIR ライブラリ内部制約の確認と、`gfx900` 関連変更の provenance map 拡張。

---

このログは「何をやったか・何を見たか・何がわかったか」を時系列で記録する。
推論・仮説は `hypothesis.md`、確定した事実は `facts.md` に分離している。
知識の集積先は `vega-rocm.md`（推論経路本体）。ここは「作業の流れ」を残す場所。

### ステータスラベル定義

| ラベル | 意味 |
| --- | --- |
| **完了** | そのフェーズの主要問いに答えた |
| **完了（部分）** | 手段は成立したが、依存待ちまたは次段あり |
| **未完了** | まだ主要観測なし |

---

## Phase 1 | 静的コード調査（MIOpen / rocBLAS / CK / Tensile）

### [完了] MIOpen: gfx900 関連 solver 経路の全件確認

#### MIOpen solver 経路で何をやったか

`/home/limonene/ROCm-project/WD-Black/ROCm-repos/` 配下の
MIOpen ソースを直接開いて、gfx900 の filter 条件を全件追った。

#### MIOpen solver 経路の主な確認先ファイル（行番号付き）

| ファイル | 行 | 内容 |
| --- | ---: | --- |
| `conv_mlir_igemm_fwd.cpp` | 188 | `StartsWith(device_name, "gfx900") return false` |
| `conv_mlir_igemm_bwd.cpp` | 68 | 同上 BWD |
| `conv_mlir_igemm_wrw.cpp` | 69 | 同上 WRW |
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

#### MIOpen solver 経路でわかったこと

- MIOpen は「候補列挙 + `IsApplicable` フィルタ」方式（if-else フォールバックチェーンではない）
- gfx900 では MLIR iGEMM（FWD/BWD/WRW）が除外 → ASM v4r1 dynamic / DLOPS / Winograd へ流れる設計
- XDLops 系は共通ガードで gfx900 を弾く（`IsXdlopsSupport` が false）
- Winograd / 旧ASM にも gfx900 明示条件が残っている

---

## Phase 1.5 | legacy / retired repo の射程確認

### [完了（部分）] `00_legacy-repos` の初回棚卸し

#### `00_legacy-repos` 棚卸しで何をやったか

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos/` を列挙
- `ROCR-Runtime` / `Tensile` / `vllm` の README と remote を確認
- `MIOpen` legacy clone の状態を確認

#### 確認できた対象

- `ROCR-Runtime`
- `Tensile`
- `MIOpen`
- `ROCm/vllm`

#### `00_legacy-repos` 棚卸しでわかったこと

- `ROCR-Runtime` README は retired を明記し、移行先として `ROCm/rocm-systems` を案内している
- `Tensile` README は retired を明記し、移行先として `ROCm/rocm-libraries` を案内している
- `ROCm/vllm` README は retired を明記し、移行先として upstream `vllm-project/vllm` を案内している
- これらは code path の証拠というより、**repo topology / ownership / integration point の再編**を示す一次資料
- `00_legacy-repos/MIOpen` は remote は `https://github.com/ROCm/MIOpen`、branch は `develop_deprecated`、HEAD は `06977176a` で、working tree 比較が可能

#### `00_legacy-repos` 棚卸しの含意

- ROCm の歴史は「arch support の後退」だけでなく、**repo 単位の retirement と統合先移動**でも進んでいる可能性が高い
- この軸は `ROCm -> TheRock -> rocm-libraries / rocm-systems` の再編や、上位運用層の upstream 回帰を読む手掛かりになる

### [完了] legacy MIOpen clone の初回比較

#### legacy MIOpen 初回比較で何をやったか

- `00_legacy-repos/MIOpen` と `WD-Black/ROCm-repos/MIOpen` の `gfx900` / `MLIR` / `sramecc` / Find-db docs を比較
- shallow 判定、branch 名、HEAD commit を確認
- `conv_mlir_igemm_*`、`target_properties.cpp`、Find-db / immediate mode docs の代表箇所を目視比較

#### legacy MIOpen 初回比較でわかったこと

- `00_legacy-repos/MIOpen` は `develop_deprecated` HEAD (`06977176a`) で **non-shallow**
- 一方、`WD-Black/ROCm-repos/MIOpen` は `main` の `e5c6ce1` で **shallow**
- よってこの初回比較は「厳密な年代比較」より、**退役ブランチでも gfx900 痕跡がどう残っているか**を見る比較として読むべき
- legacy 側にも `ConvMlirIgemmFwd/Bwd/Wrw` の `gfx900` 明示 reject と `ROCm/llvm-project-private/issues/389` 参照が残る
- legacy 側にも `WORKAROUND_ISSUE_1204` と `gfx900_56 / gfx900_64` の Find-db / immediate mode docs が残る
- 違いとして、legacy 側は standalone repo 由来の `docs/*.rst` / `src/solver/conv/*` 構成、local official snapshot 側は `doc/src/*.md` / `src/solver/*` 構成になっている

#### legacy MIOpen 初回比較の含意

- retired / deprecated 化は、少なくとも MIOpen では `gfx900` 痕跡の即時削除を意味していない
- まず起きているのは repo status と file layout の再編であり、`gfx900` 向け分岐・workaround・docs 自体は引き続き可視である

### [完了] legacy MIOpen の layout 再編と last-touch の切り分け

#### layout 再編調査で何をやったか

- `git log --follow --name-status` で solver / docs の rename・作成点を追跡
- `git blame` で `gfx900` 関連の代表行が最後に誰に触られたかを確認

#### 確認できた主な commit

- `7b36cef67` (2024-05-31, Evgenii Averin, `[NFC] Move convolution solvers to solver/conv directory (part 1) (#2962)`)
  - `src/solver/conv_mlir_igemm_*.cpp` -> `src/solver/conv/conv_mlir_igemm_*.cpp`
  - `R100` rename で、中身の意味変更はなし
- `992a835c2` (2024-03-22, Lisa, `Doc cleanup (#2783)`)
  - `docs/find_and_immediate.md` / `docs/embed.md` を廃止し、
    `docs/how-to/find-and-immediate.rst` / `docs/install/embed.rst` を作成
- `5e791ce2c` (2025-01-10, Jeffrey Novotny, `Refactor and reformat MIOpen index and install docs (#3409)`)
  - `docs/install/embed.rst` の `gfx900_56` 例を含む install docs を整形し直す

#### 代表行の blame

- `ConvMlirIgemmFwd/Bwd/Wrw` の `if(StartsWith(device_name, "gfx900")) return false;`
  - `d1a42ea69` (2021-12-22, Zhuoran Yin, `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`)
- private issue comment の URL 更新
  - `2c1bdc775` (2023-12-13, Artem Tamazov, `[Doc] Fix URLs ... (#2597)`)
- `WORKAROUND_ISSUE_1204`
  - `8498875ae` (2021-10-21, Artem Tamazov, `[WORKAROUND] Enforce "no sramecc feature" for gfx900. (#1231)`)
- `docs/how-to/find-and-immediate.rst` の `gfx900 with 64/56 CUs`
  - `992a835c2` (2024-03-22)
- `docs/install/embed.rst` の `gfx900_56` 例
  - 行によって `992a835c2` または `5e791ce2c`

#### layout 再編調査の含意

- 2024-2025 の目立つ変更は、主に **layout / doc-format / URL / install doc 整形** であり、
  `gfx900` support policy 自体を新たに動かした痕跡は薄い
- `gfx900` に対する実質的な中身変更として強いのは、現時点では
  `2021-10-21` の `sramecc` workaround と `2021-12-22` の MLIR 除外である

### [完了] PR #1328 / #1231 の public 文脈確認

#### PR #1328 / #1231 文脈確認で何をやったか

- `gh pr view` で `ROCm/MIOpen#1328` と `ROCm/MIOpen#1231` の body / comments / reviews / files / commits を確認
- `gh issue view` で `ROCm/MIOpen#1204` の issue 本文と comment thread を確認

#### PR #1328 / #1231 文脈確認でわかったこと

- `#1231` (`[WORKAROUND] Enforce "no sramecc feature" for gfx900.`) の body は、
  internal `SWDEV-303062` に加えて public issue `#1204` comment を解決対象として明記している
- `#1204` comment thread では、Artem Tamazov が
  「HIP runtime が `gfx900` に SRAMECC feature を誤報し、MIOpen が `sramecc-` を target name に付加し、
  COMGR が invalid target として reject する」という説明を public に与えている
- `#1231` comment では Jun Liu が「legacy ASIC を使う community user に影響するため cherry-pick したい」と述べている
- `#1328` (`[MLIR] Disable gfx900 from non-xdlops solver`) の body では、
  private `llvm-project-private#389` に基づき
  - MLIR commit を ROCm 5.1 release branch へ bump
  - non-xdlops MLIR solver から `gfx900` を除外
  - ctest 側でも `gfx900` を無効化
  - `MIOPEN_TEST_VEGA` を `GFX900` / `GFX906` に分割
  することが列挙されている
- `#1328` の comment では、「ROCm 5.1 向けに MLIR solver を tune する前にこの PR を入れる必要がある」と明示されている

#### PR #1328 / #1231 文脈確認の含意

- `#1231` は public issue からも理由が読める defensive workaround であり、
  lower-layer / driver-runtime 側の target-feature misreport を MIOpen userspace 側で吸収する判断だった
- `#1328` は根本理由自体は private issue に閉じているが、
  public PR 文脈からも「ROCm 5.1 release/tuning surface から `gfx900` MLIR non-xdlops を外す」release-engineering 上の判断だったことまでは読める

---

### [完了] rocBLAS / Tensile: gfx900 生存証跡確認

#### rocBLAS / Tensile の主な確認先ファイル

| ファイル | 行 | 内容 |
| --- | ---: | --- |
| `rocblas/library/src/tensile_host.cpp` | 232, 238, 240 | `getLazyLoadingArch` で `gfx900→LazyLoadingInit::gfx900` |
| `rocblas/library/src/tensile_host.cpp` | 1232 | "hipBlasLT failed, falling back to tensile." |
| `rocblas/library/src/tensile_host.cpp` | 1161 | "No Tensile solution found for XF32, fall back to FP32" |
| `rocblas/CMakeLists.txt` | 80-85 | TARGET_LIST_ROCM_5.6〜7.1 に gfx900 継続 |
| `hipblaslt/.../tensile_host.cpp` | 1932, 1944, 1946, 2239 | hipBLASLt 内部でも gfx900 LazyLoading 経路 |
| `miopen/src/gemm_v2.cpp` | 245, 640, 684, 687 | GEMM backend 切替（hipBLASLt/rocBLAS） |

#### rocBLAS / Tensile でわかったこと

- rocBLAS は「hipBLASLt → Tensile」「XF32 → FP32」の二段フォールバックを明示実装
- Tensile/lazy catalog に `gfx900` 向けエントリが設計概念として存在（`TensileLibrary_lazy_gfx900.yaml`, `fallback_gfx900.hsaco`）
- hipBLASLt 内部にも gfx900 LazyLoading 経路あり

---

### [完了] CK / Tensile: dot4 非対応時フォールバック確認

#### CK / Tensile の主な確認先ファイル

| ファイル | 行 | 内容 |
| --- | ---: | --- |
| `composablekernel/include/ck/utility/inner_product.hpp` | 179-201 | dot4 有無で積和実装が分岐 |
| `Tensile/AsmCaps.py` | 128, 155, 158, 159 | ISA(9,0,0) で `v_dot4*` が False |
| `Tensile/Code.py` | 628, 635 | `int8 not implemented yet for gfx900` コメント |
| `legacy_composable_kernel/.../config.hpp` | 50-90 | gfx900 は `CK_USE_AMD_V_MAC_F32`、dot4/xdlops マクロ無効 |

#### CK / Tensile でわかったこと

- dot4 ability が立たない世代（gfx900 含む）向けの逐次積和フォールバックが正式実装されている
- これは gfx900 専用ではなく「capability-based な汎用実装」であり、設計の寛容性の証拠

---

### [完了] target_properties / IsMlirSupportedHardware の確認

#### target_properties / IsMlirSupportedHardware の主な確認先

| ファイル | 行 | 内容 |
| --- | ---: | --- |
| `miopen/src/target_properties.cpp` | 51-52 | `"Vega10"→"gfx900"`, `"gfx901"→"gfx900"` |
| `conv_mlir_igemm_fwd.cpp` | 付近 | `IsMlirSupportedHardware()` に gfx900 は含まれる（除外は別条件） |

#### target_properties / IsMlirSupportedHardware でわかったこと

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

#### 実行したケース（`miopen-driver conv -S <solver>` による強制指定）

| 強制 solver | 結果 | エラーメッセージ |
| --- | --- | --- |
| `ConvMlirIgemmFwd` | 失敗 | `miirLowerTuningParams MIIR_INVALID_PARAM` / `rc=0x7` |
| `ConvCkIgemmFwdV6r1DlopsNchw` | 不成立 | `not applicable to the current problem` / `rc=0x3` |
| `ConvHipImplicitGemmForwardV4R5Xdlops` | 失敗 | xdlops kernel compile 失敗 (`intrin_mfma_*`, `gcnasm_mfma_*`) / `Code object build failed` → `rc=0x7` |
| `ConvHipImplicitGemmFwdXdlops` | abort | `std::vector::operator[]` assertion / `EXIT=134` |
| `ConvHipImplicitGemmGroupFwdXdlops` (g=2) | 不成立 | `not applicable` / `rc=0x3` |
| `ConvAsmImplicitGemmV4R1DynamicFwd_1x1` | 部分到達 | `CompileSolution` まで進んだが GPU memory access fault |

#### DLOPS 追加グリッド（`ConvCkIgemmFwdV6r1DlopsNchw` 全15ケース以上）

- NCHW/NHWC, 1x1/3x3, n=1/16/32, g=1/2, C/K=64/128/256, stride=1/2, `-s 1` 有効化
- **全件 `not applicable (rc=0x3)`**
- 含意: DLOPS 系は「候補として登録されている」と「その問題で成立する」は別問題

#### dtype 差分テスト（3x3, NCHW, n=16, c=64, k=64, 自然選択）

| dtype | 選択 solver |
| --- | --- |
| FP16 | `ConvOclDirectFwd` |
| BFP16 | `GemmFwdRest` |
| FP32 | `ConvBinWinograd3x3U` / `ConvAsm1x1U` / `ConvHipImplicitGemmV4R1Fwd` 等 |

#### FP32 自然選択（`fallback_confirmed` 相当）

以下のsolver が自然選択で成功している（`runtime_verified`）:

- `ConvBinWinograd3x3U`
- `ConvAsm1x1U`
- `ConvHipImplicitGemmV4R1Fwd` (= ASM implicit GEMM v4r1 系)

**ログ保存先**: `~/vega_path_check_logs/` 配下の各 `<CASE_ID>.log`

---

### [完了] solver 失敗モードの3分類確立

| 分類 | rc | 症状 | 意味 |
| --- | --- | --- | --- |
| applicability reject | `0x3` / `rc=3` | `not applicable to the current problem` | IsApplicable が false |
| build 失敗 | `0x7` / `rc=7` | `MIIR_INVALID_PARAM` / `Code object build failed` | コンパイル/ライブラリ失敗 |
| runtime abort | `EXIT=134` | `std::vector::operator[]` assertion | 到達したが内部 abort |

---

## Phase 3 | rocMLIR 静的解析 + 接続点調査

### [完了] MIOpen → rocMLIR 境界の特定

#### 確認先

| ファイル | 行 | 内容 |
| --- | ---: | --- |
| `miopen/src/mlir_build.cpp` | - | `check_miir_error()` が `MIIR_INVALID_PARAM` を例外化 |
| `miopen/src/hipoc/hipoc_program.cpp` | - | `.mlir` 拡張子分岐 → `BuildCodeObjectInMemory` → `binary.empty()` で throw |
| `rocmlir-lib.cpp` | - | `miirCreateHandle` が失敗時に `nullptr` を返す設計 |
| `fin_interface.cpp` | - | solver id: 98=FWD / 99=BWD / 100=WRW / 80=V4R5Xdlops / 114=DLOPS / 128=FwdXdlops |

**代表失敗ポイント（推定）**: `parseConvConfig`, `isApplicable`, `RockEnabled`, 以降 lower/gen 経路

**成果物**: `trace_map_static.md` に MIOpen→rocMLIR 静的結線を固定

---

### [完了] LD_PRELOAD フック試行（失敗記録）

#### やったこと

- `tools/miir_preload_trace.c` を作成し、MIIR C API フックを試みた
- `run_vega_path_case_miir_trace.sh` で実行

#### 結果

- `MIIR_INVALID_PARAM` は再現
- 期待した `[MIIR_TRACE]` ログが出ない
- 調査: `libMIOpen.so` には `miopen::Miir*` ラッパは `GLOBAL DEFAULT` にあるが、`miir*` C API シンボルが見えない

**結論**: 現行 LD_PRELOAD 方式では MIIR 呼び出しを捕捉できない。
別手段（debug ビルド、ソース追加ログ）が必要。

---

## Phase 4 | debug ビルド試行（rocMLIR + MIOpen）

### [完了（部分）] MIOpen debug ビルド

#### 作成した補助スクリプト

- `tools/build_miopen_debug_local.sh`（`ROCMLIR_PREFIX` / `rocMLIR_DIR` を受け取れるよう設計）
- `tools/run_case_with_local_miopen.sh`（ローカル prefix 向け差し替え実行）
- `miopen_debug_rebuild_plan.md`（手順書）

#### 失敗経緯とその対処

| ステップ | 結果 | 対処 |
| --- | --- | --- |
| 初回 configure | `nlohmann_json` 不足 | `nlohmann-json` 導入 |
| 再 configure | `Could NOT find rocMLIR` / `Could not find libMLIRMIOpen` | rocMLIR を先に local install する必要と判明 |
| → rocMLIR build が前提と確定 | - | - |

**現状**: rocMLIR install 待ちで停止。`rocMLIRConfig.cmake` 未生成。

---

### [完了（部分）] rocMLIR ビルド試行

#### 建てたビルドディレクトリ群

```text
tmp/rocmlir-build-*          # build ディレクトリ（複数試行）
tmp/rocmlir-prefix-*         # install prefix（複数試行）
tmp/rocmlir_build_*.log      # ビルドログ
```

#### 試行経緯

| 試行 | generator | 結果 |
| --- | --- | --- |
| 初回 | なし（cmake デフォルト） | `Ninja` 未導入で失敗 |
| 再試行 | `Unix Makefiles` | `pybind11` 不足で失敗 |
| 再々試行 | `Unix Makefiles` | configure は通るが長時間化・割り込み終了 (`EXIT:130`) |
| detached 起動 | `Unix Makefiles` | 割り込み耐性を `nohup` で確保。ただし Makefiles だと configure フェーズが極端に遅い |
| detached 起動（Ninja化） | `Ninja` | configure/generate までは到達したが、workspace 側 `tmp` を build root にしたため `llvm-min-tblgen: Permission denied (code=126)` で停止 |
| 現行 detached 起動 | `Ninja` + build root=`/tmp` | noexec 回避のため build root を `/tmp` に変更して再起動。現在 build 進行中。 |

#### 依存追加対応

- `pybind11`: `sudo pacman -S pybind11` → configure で `Found pybind11` を確認

#### 追加で判明したこと

- 調査ワークスペース配下の `tmp/` は noexec 相当で、rocMLIR/LLVM ビルド中に生成される補助実行ファイル（例: `llvm-min-tblgen`）を実行できない
- そのため detached 起動スクリプト `tools/start_rocmlir_build_detached.sh` は、既定 generator を `Ninja`、既定 build root を `/tmp` に変更した

**現状**: `/tmp/rocmlir-build-detached-20260313_172420` で rocMLIR build が進行中。workspace 側 prefix `tmp/rocmlir-prefix-detached-20260313_172420/` に `rocMLIRConfig.cmake` が生成されたら、待機中の監視ジョブから MIOpen debug ビルドへ自動接続する構成に切り替え済み。

---

### [完了] CIFS 問題の解決 + NVMe ローカルビルド成功（2026-03-14）

#### 問題

前日からの MIOpen cmake configure が 12時間以上経過しても完了しない。
`ps aux` で確認したところ、PID 653547 (cmake) が State: D（uninterruptible sleep）で CIFS I/O 待ちに張り付いていた。

#### 根本原因

調査ソースが CIFS マウント (`//100.67.180.73/tank`) 上にあったため、cmake の大量の `stat()` / `read()` が CIFS を経由し、D-state I/O wait が頻発していた。

#### 対処

WD-Black NVMe (btrfs, `/home/limonene/ROCm-project/WD-Black/`) に MIOpen ソースを新規 clone:

```bash
cd /home/limonene/ROCm-project/WD-Black
git clone --depth 1 --branch rocm-7.2.0 https://github.com/ROCm/MIOpen.git miopen-src
```

> **劇的改善**: cmake configure が **7.5秒** で完了（CIFS では 12時間以上未完了）。

#### ビルド設定と解決したブロッカー一覧

| # | ブロッカー | 原因 | 対処 |
| --- | --- | --- | --- |
| 1 | CIFS 上で cmake configure 12h+ ハング | CIFS I/O の D-state | WD-Black NVMe にソース clone |
| 2 | rocMLIR prefix 消滅 | `/tmp` 上の前日ビルド成果物が消えていた | `-DMIOPEN_USE_MLIR=Off` で回避 |
| 3 | `--offload-arch=gfx900` がGCCで未認識 | システムGCCはHIPコンパイル不可 | `-DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++` |
| 4 | CK `v_fmac_f32` がgfx900に存在しない | gfx906+ 専用命令 | `-DMIOPEN_USE_COMPOSABLEKERNEL=Off` |
| 5 | `half_float::detail::expr` 未定義 | half 2.2.x ではこの型が削除されている | `test/verify.hpp:198` をパッチ |

#### 最終 cmake 構成

```bash
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DGPU_TARGETS="gfx900" \
  -DMIOPEN_BACKEND=HIP \
  -DMIOPEN_USE_MLIR=Off \
  -DMIOPEN_USE_COMPOSABLEKERNEL=Off \
  -DMIOPEN_ENABLE_AI_IMMED_MODE_FALLBACK=Off \
  -DMIOPEN_ENABLE_AI_KERNEL_TUNING=Off \
  -DHALF_INCLUDE_DIR=/usr/include \
  ../miopen-src
```

#### ビルド結果

- `ninja MIOpen`: 成功（libMIOpen.so ビルド完了）
- `ninja MIOpenDriver`: 成功
- `ninja install`: 成功
- 所要時間: configure 9.6秒 + ビルド数分
- ビルドディレクトリ: `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-build-20260314_135541/`
- インストール先: `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-prefix-20260314_135541/`

#### `test/verify.hpp` パッチ内容

```cpp
// 変更前（half 1.x 向け）
template <class... Ts>
auto as_double(const half_float::detail::expr<Ts...>& x)
{
    return as_double(static_cast<half_float::half>(x));
}

// 変更後（half 2.2.x 互換）
template <class T>
auto as_double(const T& x) -> std::enable_if_t<
    !std::is_same_v<std::decay_t<T>, half_float::half> &&
    std::is_convertible_v<T, half_float::half>,
    double>
{
    return as_double(static_cast<half_float::half>(x));
}
```

#### 動作確認

```bash
$ LD_LIBRARY_PATH="$PREFIX/lib" $PREFIX/bin/MIOpenDriver --help
# → 正常にヘルプ出力

$ LD_LIBRARY_PATH="$PREFIX/lib" $PREFIX/bin/MIOpenDriver conv \
    -n 1 -c 3 -H 32 -W 32 -k 16 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1
# → FP32 convolution 正常完了
```

---

### [完了] MLIR iGEMM 強制実行テスト（システム MIOpen）

MLIR 有効のシステム MIOpen（`/opt/rocm`）を使い、`-S ConvMlirIgemmFwd` を INT8 / FP32 両方で強制実行した。

#### INT8 テスト

```bash
MIOPEN_ENABLE_LOGGING=1 MIOPEN_LOG_LEVEL=6 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1 2>&1 | tee mlir_force_test.log
```

結果:

```text
CompileSolution: ConvMlirIgemmFwd
GetInvoker: ConvMlirIgemmFwd
Perf Db: record not found
MIOpen(HIP): Warning ... boost::optional::get() Assertion ... terminated
```

#### FP32 テスト

```bash
MIOPEN_ENABLE_LOGGING=1 MIOPEN_LOG_LEVEL=6 \
  /opt/rocm/bin/MIOpenDriver conv \
  -n 1 -c 3 -H 32 -W 32 -k 16 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1 2>&1 | tee mlir_force_fp32.log
```

結果: 同一パターンの `boost::optional::get()` assert クラッシュ。

#### MLIR iGEMM 強制実行テストでわかったこと

`-S` フラグは `IsApplicable()` のガードをバイパスし `CompileSolution` まで進める。
しかし gfx900 用の tuning パラメータが Perf DB に存在しないため、
`boost::optional::get()` で空値アクセスが発生しクラッシュする。

---

### [完了] 二重排除メカニズムのソースコード確定

`mlir_common.hpp` の `IsMlirSupportedHardware()` を直接確認:

```cpp
// mlir_common.hpp:42-48
inline bool IsMlirSupportedHardware(const miopen::ConvolutionContext& ctx)
{
    const auto device_name = ctx.GetStream().GetDeviceName();
    return StartsWith(device_name, "gfx900") ||    // ← gfx900 はここで TRUE
           StartsWith(device_name, "gfx906") ||
           StartsWith(device_name, "gfx908") ||
           StartsWith(device_name, "gfx90a") ||
           StartsWith(device_name, "gfx940") ||
           StartsWith(device_name, "gfx942") ||
           StartsWith(device_name, "gfx1030");
}
```

一方、`conv_mlir_igemm_fwd.cpp:188`:

```cpp
if(StartsWith(device_name, "gfx900"))
    return false;  // ← hardware check の後段で明示除外
```

**構造**: 「MLIR 対応ハード」リストには gfx900 が含まれるのに、個別 solver の `IsApplicable()` で後段除外。
この二重構造が「一見 MLIR 対応に見えるが実際は MLIR iGEMM を使えない」という混乱の根源。

---

## Phase 5 | git blame / provenance 調査

### [完了] MIOpen MLIR iGEMM gfx900 除外の根拠コミット特定

#### MLIR iGEMM 除外 provenance でやったこと

```bash
cd <ROCm_AMD_Repo>
git blame rocm-libraries/projects/miopen/src/solver/conv/conv_mlir_igemm_fwd.cpp -L 180,200
git show 2407d2f556c7635de3f4b3f009681bdd92ba82e2
git show b0f912e5244b -- conv_mlir_igemm_bwd.cpp conv_mlir_igemm_wrw.cpp
git show 2407d2f -- conv_mlir_igemm_bwd.cpp conv_mlir_igemm_wrw.cpp
```

#### 確定した結果

| 属性 | 値 |
| --- | --- |
| 除外コミット | `2407d2f556c7635de3f4b3f009681bdd92ba82e2` |
| 作者 | Zhuoran Yin (`zhuoryin@amd.com`, AMD 社員) |
| 日付 | 2021-12-22 |
| コミットメッセージ | `[MLIR] Disable gfx900 from non-xdlops solver (#1328)` |
| 対象 | FWD / BWD / WRW 全3ファイルを同一コミットで一括除外 |
| 参照 issue | `https://github.com/ROCmSoftwarePlatform/llvm-project-private/issues/389` |

#### URL 修正コミット

| 属性 | 値 |
| --- | --- |
| コミット | `b0f912e5244b` |
| 作者 | Artem Tamazov |
| 日付 | 2023-12-13 |
| 内容 | `ROCmSoftwarePlatform` → `ROCm` 組織名変更のみ（実質内容の変更なし） |

#### 重要な判明事項

- `#389` は AMD 社内の**非公開** LLVM リポジトリ（`llvm-project-private`）の issue
- 公開リポジトリ `ROCm/MIOpen #389`・`ROCm/rocMLIR #389` とは**全くの別物**（これを確認するまで空振り探索が続いていた）
- 除外は AMD 社員による意図的コミットであり、コミュニティパッチではない
- 問題根拠は LLVM/コンパイラバックエンド（AMDGPU codegen）側の制約を示唆（MIOpen/rocMLIR 本体の問題ではない）

#### 完了した後続アクション（2026-03-15）

- MIOpen PR #1328 のレビューコメント確認を完了。
  - 追加で得られた公開情報は「ROCm 5.1 までに MLIR solver tuning を進める前提の調整PR」という運用背景。
  - private issue #389 の技術本文は公開されておらず、根因の直接説明は得られず。
- 公開 `llvm-project` での gfx900 / MLIR 関連コミット・issue 照合を実施。
  - `gh search issues --repo llvm/llvm-project "gfx900 MLIR"` の open/closed 探索ではヒットなし。
  - 広め検索では `#95292`（GPU metadata attributes, 例示に `chip = "gfx900"`）を確認したが、除外根因に直結する公開issueは見つからず。

---

### [未完了] #389 の内容推定

private issue のため本文は外部から読めない。
ただし以下の間接証拠から、内容を推測している:

- `MIIR_INVALID_PARAM` が `miirLowerTuningParams` で発生（実機確認済み）
- `Disable` という語は `Remove` より「一時的/バグ回避的な無効化」のニュアンスが強い
- 参照元が `llvm-project-private` = LLVM コンパイラレベルの issue である可能性が高い

断定不可。「設計判断」か「既知バグ回避」かは未確定。

---

## Phase 5 | GitHub 履歴調査（MIOpen / ROCm changelog）

### [完了] `gfx900` の layered retreat を履歴から整理

#### layered retreat 履歴調査で何をやったか

- `MIOpen` の `git blame` / commit metadata を再確認
- 旧 `ROCm/CHANGELOG.md` と current component release note の `gfx900` 記述を release block 単位で整理
- 現行ソースに残る `gfx900` 経路と、過去の build policy 変更を突き合わせた

#### layered retreat 履歴調査でわかったこと

- `MIOpen` の MLIR iGEMM `gfx900` 除外は、AMD 社員の commit `2407d2f`（2021-12-22）で意図的に導入された
- 根拠参照先は `llvm-project-private#389` であり、公開 GitHub だけでは理由本文に到達できない
- `ROCm 5.5.0` block の `Tensile (4.36.0)`、`ROCm 6.2.0` block の `rocSOLVER (3.26.0)` では追加系記述がある一方、
  `ROCm 7.0.0` block の `hipCUB (4.0.0)` では `gfx900` が既定 build 対象から外れている
- したがって、ROCm における `gfx900` は「ある日一括で死んだ」のではなく、component ごとに時間差をもって legacy 化したと読むのが自然

#### 成果物

- `rocm-github-investigate.md`

---

## 作成した成果物ファイル一覧

### ドキュメント

| ファイル | 状態 | 内容 |
| --- | --- | --- |
| `vega-rocm.md` | 継続更新 | 主推論経路調査本体（真実源） |
| `rocm-github-investigate.md` | 完了 | GitHub 履歴 / changelog / 現行コードから見た変遷整理 |
| `reveal_hypothesis.md` | 完了 | GitHub 側の一次資料から見た ROCm 一般の設計思想仮説の検証 |
| `facts.md` | 継続更新 | 確定した事実（code/runtime_verified 分類） |
| `hypothesis.md` | 継続更新 | 仮説・解釈・検証進捗 |
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

### ログ

| ファイル | 内容 |
| --- | --- |
| `../../../WD-Black/mlir_force_test.log` | INT8 MLIR iGEMM 強制実行ログ（boost::optional crash） |
| `../../../WD-Black/mlir_force_fp32.log` | FP32 MLIR iGEMM 強制実行ログ（同上） |

### スクリプト

| ファイル | 内容 |
| --- | --- |
| `run_vega_path_case.sh` | 1ケース実行・ログ保存・抽出の半自動スクリプト |
| `run_vega_path_case_miir_trace.sh` | MIIR トレース付き実行スクリプト |
| `sync_vega-logs.sh` | ログ同期スクリプト |
| `tools/build_miopen_debug_local.sh` | MIOpen debug ビルドスクリプト |
| `tools/build_rocmlir_local.sh` | rocMLIR ビルドスクリプト |
| `tools/start_rocmlir_build_detached.sh` | rocMLIR nohup 起動スクリプト |
| `tools/run_case_with_local_miopen.sh` | ローカル MIOpen 差し替え実行 |
| `tools/miir_preload_trace.c` | LD_PRELOAD フックソース（現行方式では不成立） |

---

## Layer 6 続き: gfx900 生存経路の provenance 調査（2026-03-15）

**目的**: MLIR以外の gfx900 生存経路（ASM v4r1 dynamic, Winograd, Tensile lazy loading）の出所・導入経緯を GitHub PR/コミット/ソースコードから確定する。

### MIOpen: ASM Implicit GEMM V4R1 Dynamic

#### 導入

PR [#166](https://github.com/ROCm/MIOpen/pull/166) (2020-04-19, merged 2020-06-09)

- 作者: `carlushuang` (CONTRIBUTOR)
- タイトル: `[dynamic-igemm] add v4r1 dynamic kernel and solver, fwd fp32`
- 説明: 動的カーネルで compile 時ではなく run-time にインデックスを計算。特定テンソル次元ごとの個別カーネル生成を回避し、カーネル数を劇的に削減。パフォーマンスは 8% 以内の低下（1x1 で 2% 以内）
- ラベル: `value_high`
- gfx ターゲット: **`gfx900` / `gfx906` のみ** — `IsApplicable` で明示的に allow

#### BWD 追加

PR [#272](https://github.com/ROCm/MIOpen/pull/272) (2020-06-09, merged 2020-07-27)

- 作者: `carlushuang`
- タイトル: `[igemm_dynamic] v4r1 bwd dynamic kernel`

#### WRW バグ修正 (Vega20/gfx906)

Issue [#999](https://github.com/ROCm/MIOpen/issues/999) → PR [#1001](https://github.com/ROCm/MIOpen/pull/1001) (2021-06-22)

- 作者: `shaojiewang` (CONTRIBUTOR)
- タイトル: `[vega][fp32]fix vega asm igemmwrw kernel selection bug`
- 内容: Vega20 FP32 で `ConvAsmImplicitGemmV4R1DynamicWrw` が validation fail (max diff: 4994)
- ラベル: `bug`, `urgency_high`
- **意味**: 2021年半ばにおいても Vega 用の ASM implicit GEMM は**積極的にバグ修正されていた**

#### gfx908 FP16 追加（v4r1 系とは別の GTC 系）

PR [#680](https://github.com/ROCm/MIOpen/pull/680) (2021-01-14)

- 作者: `shaojiewang`
- `gfx908` 専用。**gfx900 は対象外**

#### 現状 (rocm-7.2.0 tag)

- `conv_asm_implicit_gemm_v4r1_dynamic.cpp` L293: `if(!(StartsWith(device_name, "gfx900") || StartsWith(device_name, "gfx906")))` → gfx900/gfx906 のみ通過
- `conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp` L142: 同上
- `conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp` L306: 同上
- GTC 系 (`conv_asm_implicit_gemm_gtc_*.cpp`): 全て `gfx908` 以降のみ

**解釈**: v4r1 dynamic は gfx900/gfx906「専用」の legacy solver として残存。GTC 系は MFMA/xdlops 必須のため gfx900 は使えない。新旧の明確な分離ライン。

---

### MIOpen: Winograd 系 Solver

**現状 (rocm-7.2.0 tag) の gfx900 許可マップ**:

| ファイル | gfx900 許可条件 |
| --- | --- |
| `conv_bin_wino3x3U.cpp` L63 | gfx803/gfx900/gfx906/gfx908 — FP32 全方向 |
| `conv_bin_winoRxS.cpp` L260-272 | FP16: gfx906/gfx908 のみ。FP32 WrW: gfx900/gfx906/gfx908。FP32 Fwd/Bwd: gfx803/gfx900/gfx906/gfx908 |
| `conv_multipass_wino3x3WrW.cpp` L490 | gfx8xx/gfx900/gfx906/gfx908 など。ただし gfx900 は CU 制限（L501: 別条件で reject の可能性あり） |
| `conv_MP_bidirectional_winograd.cpp` L203 | gfx900/gfx906/gfx908。gfx900 は CU <= 60 で別制約 (L211) |
| `conv_winoRxS.cpp` L212 | `gfx900` / `gfx906` で v21 variant 向け |

#### 注目 PR

PR [#1968](https://github.com/ROCm/MIOpen/pull/1968) (2023-02-06)

- タイトル: `[Vega20] Workaround for 25% winograd performance drop`
- 作者: `Slimakanzer`
- **意味**: 2023年にも Vega20 (gfx906) の winograd パフォーマンス問題に対するワークアラウンドが投入されている。Vega 系への保守行為が比較的最近まで行われていた証拠

#### Winograd の gfx900 分類

- これらは MFMA/xdlops を使わない旧来のバイナリ Winograd カーネル
- gfx900 が明示的に allow されている = design-time に意図的に含めた
- FP16 は gfx906 以降のみ（gfx900 の FP16 dot product 非対応を反映）
- FP32 では gfx900 が広く通る

---

### MIOpen PR #1328 (MLIR gfx900 disable) 詳細確認

#### PR 本文から判明した追加情報

- 作者: `jerryyin` (MEMBER — AMD 社員)
- マイルストーン: **ROCm 5.1**
- 変更内容:
  1. MLIR commit を ROCm 5.1 release commit に bump
  2. gfx900 を non-xdlops solver から disable
  3. gfx900 を ctest から disable (`MIOPEN_TEST_VEGA` → `MIOPEN_TEST_GFX900` / `MIOPEN_TEST_GFX906` に分離)
  4. `GFX900_DISABLED` フラグを `test_conv_igemm_mlir*` に追加

**意味**: gfx900 disable は「コード上の一行変更」ではなく、テストインフラの分離を含む計画的な切り離しだった。ROCm 5.1 マイルストーンに紐付けられており、リリース計画の一部として実行された。

---

### Tensile: gfx900 の扱い

#### PR [#1595](https://github.com/ROCm/Tensile/pull/1595) (2022-09-17)

- 作者: `cgmb` (CONTRIBUTOR — **外部コントリビュータ**)
- タイトル: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
- 説明: AMD 公式バイナリには関係ないが、**ソースからビルドするユーザーに有用**
- `gfx900` と `gfx900:xnack-` の両方を受け入れるようにした
- **非常に重要**: この PR は gfx900 を「AMD が維持する」のではなく「コミュニティが自分でビルドできるようにする」という方向の貢献

#### PR [#1862](https://github.com/ROCm/Tensile/pull/1862) (2024-01-11)

- 作者: `GZGavinZhao` (CONTRIBUTOR — **外部コントリビュータ**)
- タイトル: `Use fallback libraries for archs without optimized logic`
- 説明: 最適化ロジックファイルを持たないアーキテクチャでも `--lazy-library-loading` / `--separate-architectures` でライブラリ生成を可能に
- テスト対象に `gfx900` を含む
- **意味**: gfx900 は Tensile の lazy loading で「最適化なし fallback」経路としてサポートされている。これは AMD による最適化ではなく、コミュニティ貢献で成立した fallback メカニズム

---

### Composable Kernel (CK): gfx900

- GitHub PR 検索で CK リポジトリに gfx900 関連 PR は **0件**
- CK は xdlops/MFMA ベースの設計であり、gfx900 は最初から対象外と見られる

---

### Layer 6 調査の暫定まとめ

| 経路 | 導入元 | gfx900 向け保守実績 | 現状 |
| --- | --- | --- | --- |
| ASM v4r1 dynamic (Fwd/Bwd/Wrw) | AMD contributor (carlushuang, 2020) | Bug fix 2021年 (shaojiewang) | **残存** (gfx900/gfx906 専用) |
| Winograd (binary) | 初期 MIOpen 時代 | Perf workaround 2023年 (Slimakanzer) | **残存** (FP32 全方向、FP16 は gfx906+) |
| MLIR iGEMM (non-xdlops) | AMD employee (jerryyin) | **2021-12-22 に disable** (ROCm 5.1) | **除外** (private #389 根拠) |
| ASM GTC (xdlops) | AMD (shaojiewang, 2021~) | N/A (gfx900 は最初から対象外) | **除外** (gfx908+) |
| Tensile lazy loading | 外部 contributor (cgmb, GZGavinZhao) | fallback 2024年 | **残存** (最適化なし fallback) |
| CK iGEMM | N/A | N/A | **除外** (xdlops 前提) |

#### 新しい読み取り

1. gfx900 生存経路は「AMD が積極的に維持している」のではなく、**初期の設計判断が残存し、一部はコミュニティ貢献で延命されている**
2. Tensile PR #1595, #1862 は**明確に外部コントリビュータ**によるもの — 「AMD は gfx900 を切りたいが、コミュニティが fallback を補修している」構造が見える
3. ASM v4r1 dynamic は gfx900/gfx906 **専用**設計であり、新世代に移行する動機がない — 結果として「古い GPU 用の古い solver」がそのまま生き残った

---

### Layer 6 追加: 00_legacy-repos 横断調査（2026-03-15）

**調査対象**: `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos`

**対象 repo**: `MIOpen`, `ROCR-Runtime`, `Tensile`, `vllm`

#### retired marker の commit provenance

- `MIOpen`: `5123480a6` (`Migrating MIOpen`) — README で `ROCm/rocm-libraries` へ誘導
- `ROCR-Runtime`: `ba56a24c` (`Deprecation README message`) — `ROCm/rocm-systems` へ誘導
- `Tensile`: `c5c24022` (`Updating readme to highlight deprecation`) — `ROCm/rocm-libraries` へ誘導
- `ROCm/vllm`: `eb9d4de9eb` (`Deprecation notice`) — `vllm-project/vllm` へ誘導

#### gfx900 残存量（legacy snapshot）

- `MIOpen`: 136 行
- `ROCR-Runtime`: 25 行
- `Tensile`: 411 行
- `vllm`: 0 行

#### 代表的な残存証拠

- `MIOpen`
  - `conv_asm_implicit_gemm_v4r1_dynamic.cpp`: `gfx900/gfx906` allow
  - `conv_mlir_igemm_fwd.cpp`: `gfx900` reject
  - `target_properties.cpp`: `WORKAROUND_ISSUE_1204` (`sramecc-` misreport)
- `ROCR-Runtime`
  - `runtime/hsa-runtime/core/runtime/isa.cpp`: `gfx900`, `gfx900:xnack-`, `gfx900:xnack+`
- `Tensile`
  - `CHANGELOG.md`: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
  - `Tensile/Source/lib/include/Tensile/AMDGPU.hpp`: `gfx900` enum/parser 残存

**解釈**:

- `00_legacy-repos` は単なる旧版保管ではなく、退役宣言後の技術痕跡を確認できる forensic 層。
- Vega/gfx900 の provenance を補完する上で、現行 monorepo と併読すべき一次証拠群。

### Layer 6 追補: PR #1328 review 実データ + MiirIsConfigApplicable 経路（2026-03-15）

#### PR #1328 review 実データ

- `get_reviews`: APPROVED x2
  - `JehandadKhan` (2021-12-10)
  - `atamazov` (2021-12-12, `LGTM!`)
- `get_review_comments`: review thread comments は 0 件
- `get_comments`: issue comments は 2 件（release timing 調整の内容）

**解釈**:

- PR #1328 は technical deep discussion が公開 thread に残っていない。
- private #389 を参照する構造と合わせ、公開情報だけでは root cause の深掘りが難しい状態は継続。

#### MiirIsConfigApplicable の経路確認（legacy MIOpen）

- `src/mlir_build.cpp`
  - `MiirIsConfigApplicable(params)` は `miirLowerTuningParams(handle)` の `MIIR_SUCCESS` 判定のみ
  - `MIIR_INVALID_PARAM` などの詳細理由は Miir ライブラリ内部に閉じる
- `src/solver/conv/conv_mlir_igemm_{fwd,bwd,wrw}.cpp`
  - solver `IsApplicable()` 末尾で `MiirIsConfigApplicable(...)` を呼ぶ
  - その前段に `IsMlirSupportedHardware()` と `gfx900` 明示 reject がある
- `src/include/miopen/solver/mlir_common.hpp`
  - `IsMlirSupportedHardware()` は `gfx900` を含む

**解釈**:

- 失敗判定は「MIOpen 前段条件（hardware + explicit reject）」と「Miir 後段条件（tuning params valid）」の二層。
- `Miir` 側は public `ROCm/rocMLIR` で追跡可能。
  - `mlir/tools/rocmlir-lib/rocmlir-lib.cpp`
    - `miirCreateHandle`: `parseConvConfig` / `isApplicable` / `RockEnabled` 失敗で `nullptr`
    - `RockEnabled`: レイアウト制約 + `bf16` 非対応
    - `miirLowerTuningParams`: Applicability pipeline 実行、失敗時 `MIIR_BUILD_FAILURE`

**更新後の未解決**:

- 非公開なのは Miir 実装ではなく `llvm-project-private#389` の本文。
- 次は `MIIR_BUILD_FAILURE` が出る具体 case を再現し、MIOpen 側ログと突き合わせる。

## 現在のブロッカーと未解決事項

| 項目 | 状態 | 備考 |
| --- | --- | --- |
| ~~rocMLIR Ninja ビルド完走~~ | ~~不要化~~ | prefix 消滅のため `-DMIOPEN_USE_MLIR=Off` で回避 |
| ~~MIOpen debug ビルド~~ | **完了** | WD-Black NVMe 上でビルド成功（2026-03-14） |
| ~~`miirCreateHandle` の nullptr 分岐確定~~ | **代替確認済** | システムMIOpenでMLIR強制実行→Perf DB不在→boost::optional crash |
| MLIR 有効 Debug ビルド | 未着手 | rocMLIR を再ビルドすれば可能だが、強制実行テストで失敗メカニズムは確定済み |
| INT8 非 naive solver 自然選択 | 探索完了（未達成確定） | 既存 + 2026-03-15 追加6ケース（`-s 1`）でも全件 `ConvDirectNaiveConvFwd` |
| MIOpen PR #1328 レビューコメント確認 | **完了** | PR本文/コメント取得済み。private #389 の直接本文は公開情報では補完不可 |
| 公開 llvm-project での gfx900 MLIR 痕跡探索 | **完了（限定）** | 直接相関する公開issueは未発見。関連薄いPR `#95292`（gfx900例示）は確認 |

---

## 「やらないと決めたこと」メモ

| 内容 | 理由 |
| --- | --- |
| LD_PRELOAD での MIIR C API フック | `miir*` C シンボルが `libMIOpen.so` から直接見えないため不成立 |
| `find` / 広範囲 Glob での全ファイル探索 | タイムアウト頻発。直接パス指定・`ls` 段階アプローチに切り替え |
| MIOpen フォークによる MLIR gfx900 対応 | LLVM コンパイラレベルの問題のため MIOpen 側だけでは修正不可 |
