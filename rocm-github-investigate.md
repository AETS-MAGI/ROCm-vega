# ROCm GitHub 履歴から見る Vega/gfx900 変遷メモ

更新日: 2026-03-15
対象: `/home/limonene/ROCm-project/WD-Black/ROCm-repos/` 配下のローカル clone

## 1. この文書の目的

この文書は、ROCm の GitHub 側で Vega / `gfx900` がどのような扱いを受けてきたかを、
**ローカル clone に残っている commit history / changelog / 現行ソース**から復元するためのメモ。

主眼は次の3点:

- どのような変遷で `gfx900` の扱いが変わってきたか
- その過程で「事件」と呼べる分岐点が何だったか
- 現在の「一部では死んで見え、一部ではまだ生きている」状態がどう形成されたか

---

## 2. 結論サマリ

- `gfx900` は、ROCm で**一度に全面削除された**というより、**コンポーネントごとに別々の速度で後退した**ように見える。
- 古い時期の changelog には、むしろ `gfx900` を**追加対象・既定ビルド対象として広げる**記述が残っている。
- その一方で、2021-12-22 の MIOpen commit `2407d2f556c7635de3f4b3f009681bdd92ba82e2` により、MLIR iGEMM の `gfx900` 経路が AMD 社員によって**意図的に無効化**された。
- この無効化の根拠は公開 issue ではなく、`llvm-project-private#389` という**非公開 issue**に向けられている。ここが今回観測できた中で最も「事件性」が高い。
- さらに後年の changelog では、少なくとも hipCUB 4.0.0 で `gfx803` / `gfx900` が**既定ビルド対象から外される**方向へ移っている。
- その一方で、2022-10-05 の MIOpen commit `e5c6ce1b61233392ca8660f426fd018709c395cc` 由来の現行 tree には、
  `gfx900` 向け `sramecc-` misreport workaround と `gfx900_56` / `gfx900_64` の Find-db / immediate mode 記述が残っており、
  MLIR 経路除外後も別層の runtime / docs 整備が続いていたことが分かる。
- ただし現行ソースには、MIOpen の ASM implicit GEMM、rocBLAS/Tensile の `gfx900` lazy loading、dot4 非対応時の capability-based fallback が残っており、**完全消滅ではなく legacy / fallback path の局所的残存**という形になっている。

**要するに**:
ROCm の GitHub 履歴から見えるのは、「Vega 切り捨て」という単一イベントではなく、
`追加` -> `一部経路の private issue 起因 disable` -> `既定ビルド対象からの後退` -> `fallback だけ残存`
という、層状の変遷である。

---

## 3. 調査方法と限界

今回追えたもの:

- `git blame` / `git log` / `git show` で回収できる commit metadata
- commit message 中の PR 番号
- `ROCm/RELEASE.md` と `ROCm/tools/autotag/templates/*`、各 component `CHANGELOG.md` に残る release 記述
- 現行ソースに残る `gfx900` 分岐・fallback・lazy-loading 経路

今回のローカル clone **だけでは追えない**もの:

- GitHub issue の本文・コメント・リアクション・close 理由
- PR review comment の全文
- private repository (`llvm-project-private`) 側 issue の内容
- GitHub UI 上の現在の label / state / cross-link

したがって本メモの「GitHub の状況」とは、
**Git object と changelog から復元できる範囲の GitHub archaeology** を意味する。
完全な issue / PR 追跡には、後日ネットワーク付きの追加調査が必要。

補足:

- 以前の clone では `ROCm/CHANGELOG.md` を直接使えていたが、現在の WD-Black snapshot の `ROCm` repo では
  public release 履歴の主要断片が `RELEASE.md` と `tools/autotag/templates/*` に分散している。
- したがって、release 系の歴史は「同じ public evidence をどのファイルが担っているか」自体も再編されているとみるべき。

---

## 4. 見た主要リポジトリ / 主要ファイル

- `ROCm/README.md`
- `ROCm/RELEASE.md`
- `ROCm/tools/autotag/templates/*`
- `rocm-libraries/projects/miopen`
- `rocm-libraries/projects/rocblas`
- `composable_kernel`
- `00_legacy-repos/Tensile`
- `00_legacy-repos/ROCR-Runtime`
- `00_legacy-repos/vllm`
- `00_legacy-repos/MIOpen`
- `rocMLIR`
- `llvm-project`
- `TheRock/README.md`

ただし、今回もっとも強い証拠が得られたのは `MIOpen` と `ROCm` 側 release note 群。

### 4.1 00_legacy-repos スナップショット（2026-03-15 採取）

調査対象を `/home/limonene/ROCm-project/WD-Black/ROCm-repos/00_legacy-repos` まで拡張し、
退役宣言の commit provenance と `gfx900` 残存量を固定した。

| repo | branch | latest commit | retired marker commit | retired marker の案内先 | `gfx900` ヒット行数 |
|---|---|---|---|---|---|
| MIOpen | `develop_deprecated` | `06977176a` (`Migrating MIOpen`) | `5123480a6` | `ROCm/rocm-libraries` | 136 |
| ROCR-Runtime | `amd-staging_deprecated` | `ba56a24c` (`Deprecation README message`) | `ba56a24c` | `ROCm/rocm-systems` | 25 |
| Tensile | `develop_deprecated` | `e8a8999e` | `c5c24022` (`Updating readme to highlight deprecation`) | `ROCm/rocm-libraries` | 411 |
| vllm (ROCm fork) | `main` | `eb9d4de9eb` (`Deprecation notice`) | `eb9d4de9eb` | `vllm-project/vllm` | 0 |

補足:

- retired marker は README 冒頭の caution block で、`git blame` 上も 2025 年の比較的新しい commit に集中している。
- `vllm` だけは ROCm fork の retire を明示しつつ upstream へ回帰する形で、他 3 repo は ROCm monorepo 群（`rocm-libraries` / `rocm-systems`）へ吸収される構図。

---

## 5. 変遷の時系列整理

### 5.1 昔は「追加・既定対象化」の流れも存在した

以前の clone で回収した `ROCm/CHANGELOG.md` と、現 WD-Black snapshot の
`Tensile/CHANGELOG.md` には、少なくとも以下のような記録が残っている。

- `rocSOLVER (3.26.0, ROCm 6.2.0 block)` の `Changed` に `Added gfx900 to default build targets.`
- `Tensile (4.36.0, ROCm 5.5.0 block)` の `Added` に `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`

観測:

- これは、ある時期の ROCm ecosystem では `gfx900` が「既に死んだ完全な過去資産」ではなく、**build target / packaging target としてまだ拡張対象だった**ことを示す。
- 少なくとも component ごとには、`gfx900` を広げる方向の作業が実在した。

補足:

- ここでの記述は ROCm 全体の単一方針ではなく、**個別 component の release note** である。
- 少なくとも `ROCm 5.5.0` block に Tensile の追加系記述、`ROCm 6.2.0` block に rocSOLVER の既定 target 追加、`ROCm 7.0.0` block に hipCUB の既定 target 後退があり、**release block を跨いで追加系と後退系が共存**している。
- この時点から既に、「全体として統一された support policy」より**component ごとの局所最適**で動いていた可能性が高い。

### 5.2 2021-12-22: MIOpen が MLIR iGEMM の gfx900 を明示 disable

`git blame` で確定した最重要イベント:

- commit: `2407d2f556c7635de3f4b3f009681bdd92ba82e2`
- 日付: 2021-12-22
- 作者: Zhuoran Yin (`zhuoryin@amd.com`)
- 件名: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`

この commit により、MIOpen の以下3ファイルで `gfx900` が同時に除外された。

- `conv_mlir_igemm_fwd.cpp`
- `conv_mlir_igemm_bwd.cpp`
- `conv_mlir_igemm_wrw.cpp`

現行ソースでも、各ファイルには `gfx900` に対する明示的な reject が残っている。

重要なのは、除外コードの直上/近傍コメントが次を参照していること:

```cpp
// Refer to https://github.com/ROCm/llvm-project-private/issues/389
```

意味:

- これは公開の `ROCm/llvm-project` ではなく、**非公開の `llvm-project-private`** issue。
- つまり、MIOpen の公開ソースからは「無効化した」という事実までは追えるが、**なぜ無効化したかの核心説明は public GitHub から見えない**。

ここが「事件性」の高い点:

- `gfx900` の MLIR iGEMM 経路は、単なる自然陳腐化ではなく、**AMD 社員が private LLVM issue を根拠に、意図的に止めた**ことが読み取れる。
- 公開 GitHub 上で理由が完結せず、private tracker に根拠が隠れているため、後から見る利用者には「突然死」に見えやすい。

### 5.3 public な “MLIR 対応” 表明と、solver 側の後段除外が共存した

静的解析からは、MIOpen 内部に次の二重構造がある。

- `IsMlirSupportedHardware()` には `gfx900` が含まれる
- しかし `ConvMlirIgemm{Fwd,Bwd,Wrw}::IsApplicable()` 側で `gfx900` を後段 reject する

解釈:

- public-facing には「MLIR 対応ハード」に見える
- しかし実際の solver 適用段階では `gfx900` が使えない

この構造は、GitHub 履歴の観点でも重要で、**support の看板と実働 solver の実情がズレ始めていた**ことを示す。

推測ではあるが、これは「全面撤去するには影響が大きいので対応表記や基盤は残しつつ、問題のある solver だけ個別停止した」という経路だった可能性が高い。

### 5.4 2022-10-05: MIOpen に gfx900 向け runtime workaround と docs 記述が残る

WD-Black 上の現行 MIOpen tree を `git blame` で追うと、
次の `gfx900` 直結コード / docs が commit `e5c6ce1b61233392ca8660f426fd018709c395cc`
（2022-10-05, Jehandad Khan, subject: `v2.18.0 release notes`）由来で残っている。

- `src/target_properties.cpp`
  - `#define WORKAROUND_ISSUE_1204 1 // ROCm may incorrectly report "sramecc-" for gfx900.`
  - `gfx900` だけ `sramecc_reported` を空にして、誤報を runtime 側で吸収する
- `doc/src/embed.md`
  - `gfx906_60;gfx900_56` を Find-db embed 例として明示
  - `-DMIOPEN_EMBED_DB=gfx900_56` の具体例を記載
- `doc/src/find_and_immediate.md`
  - system Find-Db populated architecture として `gfx900 with 64 CUs` / `gfx900 with 56 CUs` を記載

読み取り:

- 2021 の MLIR iGEMM 除外のあとでも、MIOpen の別層では `gfx900` 向けの runtime 正規化と docs 整備が続いていた。
- つまり `gfx900` の扱いは、単純な一本線の「縮退」ではなく、
  **solver では止まりつつ、DB / metadata / docs / 旧 solver 経路では明示対応が残る**という非単調な履歴になっている。

### 5.5 2023-12-13: private issue 参照は残したまま URL だけ更新

別の関連 commit:

- commit: `b0f912e5244b`
- 日付: 2023-12-13
- 作者: Artem Tamazov
- 内容: `ROCmSoftwarePlatform` -> `ROCm` への URL 更新

重要なのは、この変更で**issue の private 性は解消されていない**こと。

つまり:

- 公開コードには今も「この issue を見よ」という形跡がある
- しかしその issue 自体は外部から読めない

これは単なる cosmetic fix ではなく、**“理由への参照は残るが、その理由は公開されない” 状態が維持された**ことを意味する。

### 5.5.1 retired / deprecated MIOpen branch でも、その痕跡は残っている

`00_legacy-repos/MIOpen` の clone 完了後に確認できたこと:

- branch: `develop_deprecated`
- HEAD: `06977176a`
- repository は non-shallow

この retired / deprecated branch にも、次が残っている。

- `ConvMlirIgemmFwd/Bwd/Wrw` の `gfx900` 明示 reject
- `ROCm/llvm-project-private/issues/389` 参照
- `WORKAROUND_ISSUE_1204` (`sramecc-` misreport workaround)
- `gfx900_56 / gfx900_64` を含む Find-db / immediate mode docs

ただし比較上の注意:

- `WD-Black/ROCm-repos/MIOpen` 側は `main` の `e5c6ce1` しか持たない shallow snapshot であり、
  こちらは strict な full-history 比較対象ではない
- したがってここで強く言えるのは、**repo status が deprecated になっても、少なくとも MIOpen では gfx900 痕跡は引き続き tree 上に残っている**という点である

読み取り:

- repo の retirement / migration は、必ずしも arch-specific workaround や legacy docs の即時消去と同義ではない
- まず先に起きるのは、repo status と file layout の再編であり、arch-specific 痕跡はその後もしばらく残りうる

### 5.6 後年には、少なくとも一部 component で gfx900 は既定ビルド対象から外れた

以前の clone で回収した `ROCm/CHANGELOG.md` の hipCUB 4.0.0 には、次の記述がある。

- `The AMD GPU targets gfx803 and gfx900 are no longer built by default.`
- `If you want to build for these architectures, specify them explicitly in the AMDGPU_TARGETS cmake option.`

読み取り:

- これは「完全削除」ではなく、**既定 build からの後退**。
- つまり `gfx900` はこの段階で「放っておけば付いてくる target」ではなく、**明示 opt-in が必要な legacy target**に移った。

この種の変更は、利用者体験としてかなり大きい。

- ソース上には分岐が残っていても
- バイナリや CI の既定対象から外れると
- 実質的には regression が検出されにくくなる

結果として、support は「コード上では残っているのに、運用上は細っていく」。

### 5.7 それでも現行コードには gfx900 残存経路がある

今回の静的調査で、現行 tree にはまだ以下が残っていた。

- MIOpen の ASM implicit GEMM v4r1 dynamic 系は `gfx900/gfx906` を明示許可
- rocBLAS の `tensile_host.cpp` には `gfx900 -> Tensile::LazyLoadingInit::gfx900`
- Tensile capability table では ISA `(9,0,0)` で `v_dot4*` を false としつつ、dot4 非対応時の fallback 実装が別に用意されている

これは非常に重要で、`gfx900` は ROCm 内で「完全に存在しない arch」になったのではなく、**新経路では脱落しつつ、旧経路・fallback・catalog 側に残り続けた**と読める。

### 5.8 Layer 6 補遺: 生存経路ごとの provenance（PR/作者/適用条件）

ここでは、既存の「残っている/消えた」の記述を一段具体化し、
**どの経路を誰が導入し、誰が補修し、現在どの条件で生きているか**を PR ベースで固定する。

#### 5.8.1 MIOpen: ASM v4r1 dynamic は「gfx900/gfx906 専用 legacy solver」として残存

- 導入 PR: `ROCm/MIOpen#166` (`[dynamic-igemm] add v4r1 dynamic kernel and solver, fwd fp32`, 2020-04-19)
  - author: `carlushuang` (`CONTRIBUTOR`)
  - 目的: shape ごとの kernel 乱立を抑えるための dynamic index 計算導入
- 拡張 PR: `ROCm/MIOpen#272` (`[igemm_dynamic] v4r1 bwd dynamic kernel`, 2020-06-09)
- Vega 修正 PR: `ROCm/MIOpen#1001` (`[vega][fp32]fix vega asm igemmwrw kernel selection bug`, 2021-06-22)
  - 発端 issue: `ROCm/MIOpen#999`（Vega20 で `ConvAsmImplicitGemmV4R1DynamicWrw` validation fail）

`rocm-7.2.0` tag 相当の solver 条件（`IsApplicable`）:

- `conv_asm_implicit_gemm_v4r1_dynamic.cpp`: `gfx900` / `gfx906` のみ許可
- `conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp`: `gfx900` / `gfx906` のみ許可
- `conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp`: `gfx900` / `gfx906` のみ許可

対照的に GTC 系 (`conv_asm_implicit_gemm_gtc_*`) は `gfx908+`（xdlops 前提）で、`gfx900` は通らない。

読み取り:

- `gfx900` は新しい asm 系に追随して残ったのではなく、**v4r1 という旧系が専用条件で生き残った**。
- 2021 の Vega20 バグ修正が入っているため、少なくとも ROCm 4.x 期には「放置」ではなく局所補修が行われていた。

#### 5.8.2 MIOpen: Winograd 系は FP32 側で gfx900 を広く許可

`rocm-7.2.0` tag 相当で確認した代表例:

- `conv_bin_wino3x3U.cpp`: `gfx803/gfx900/gfx906/gfx908`
- `conv_bin_winoRxS.cpp`:
  - FP16: `gfx906/gfx908`
  - FP32 WrW: `gfx900/gfx906/gfx908`
  - FP32 Fwd/Bwd: `gfx803/gfx900/gfx906/gfx908`
- `conv_MP_bidirectional_winograd.cpp`: `gfx900/gfx906/gfx908`（追加制約あり）
- `conv_winoRxS.cpp`: `gfx900/gfx906` 系条件が残存

関連 PR:

- `ROCm/MIOpen#1968` (`[Vega20] Workaround for 25% winograd performance drop`, 2023-02-06)

読み取り:

- Winograd は MLIR と異なり、**Vega 系を後年まで局所補修しながら維持**していた層がある。
- ただし FP16 側は `gfx906+` 側に寄るため、`gfx900` の主戦場は FP32 と見るのが自然。

#### 5.8.3 MIOpen: PR #1328 は「テスト分離を含む計画的切り離し」

`ROCm/MIOpen#1328`（ROCm 5.1 milestone）本文から確認できる変更:

- MLIR commit を ROCm 5.1 系へ bump
- `gfx900` を non-xdlops solver から disable
- ctest から `gfx900` を disable
  - `MIOPEN_TEST_VEGA` を `MIOPEN_TEST_GFX900` / `MIOPEN_TEST_GFX906` に分離
  - `test_conv_igemm_mlir*` に `GFX900_DISABLED` を導入

読み取り:

- これは単なる `IsApplicable` の一行変更ではなく、**CI/test policy まで含む切り離し**。
- したがって MLIR 経路の `gfx900` 退場は、偶発ではなく release 計画に乗った判断だった。

#### 5.8.4 Tensile: gfx900 残存の一部は外部 contributor による補修

- `ROCm/Tensile#1595` (`Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`, 2022-09-17)
  - author: `cgmb` (`CONTRIBUTOR`)
  - PR 本文に「AMD 公式バイナリ向けではなく、source build 利用者向け」の明示あり
  - `gfx900` / `gfx900:xnack-` の両方を受け付ける方向へ補修
- `ROCm/Tensile#1862` (`Use fallback libraries for archs without optimized logic`, 2024-01-11)
  - author: `GZGavinZhao` (`CONTRIBUTOR`)
  - lazy loading / separate architectures 有効時でも、最適化 logic がない arch 用 fallback library を生成可能化
  - テスト例の対象に `gfx900` を含む

読み取り:

- `gfx900` の Tensile 側残存は「AMD 本流の最適化継続」というより、
  **外部 contributor が source-build/fallback 経路を修復して実用性を維持**している側面が強い。

#### 5.8.5 ここまでの provenance まとめ

| 経路 | 導入/主要更新 | 主体 | 現在の `gfx900` 状態 |
|---|---|---|---|
| MIOpen MLIR non-xdlops | `#1328` | AMD (`MEMBER`) | disable |
| MIOpen ASM v4r1 dynamic | `#166`, `#272`, `#1001` | contributor（AMD 関連） | `gfx900/gfx906` 専用で残存 |
| MIOpen Winograd | 複数、近年 `#1968` | contributor（AMD 関連含む） | FP32 側で残存 |
| Tensile fallback / arch parsing | `#1595`, `#1862` | 外部 contributor | source-build/fallback で残存性強化 |

要点:

- `gfx900` は「全面維持」でも「全面削除」でもない。
- **新経路（MLIR/GTC）からは外れ、旧経路（v4r1/Winograd）と fallback（Tensile）で残る**。
- その残り方には、AMD の過去実装 + 後年の外部補修が混在している。

### 5.9 00_legacy-repos から見える「退役後も残る gfx900 層」

retired 宣言のあるレポジトリでも、`gfx900` 参照は非自明な密度で残っている。

#### 5.9.1 MIOpen (legacy snapshot)

代表例:

- `src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp`
  - `gfx900/gfx906` allow 条件が残存
- `src/solver/conv/conv_mlir_igemm_fwd.cpp`
  - `gfx900` reject 条件が残存
- `src/target_properties.cpp`
  - `WORKAROUND_ISSUE_1204` (`gfx900` の `sramecc-` 誤報吸収)
- `docs/install/embed.rst` / `docs/how-to/find-and-immediate.rst`
  - `gfx900_56`、`gfx900 with 64 CUs` など DB/運用記述が残存

読み取り:

- MIOpen は retired であっても、`gfx900` の「実行経路」「拒否経路」「運用ドキュメント」が同時に残る。
- これは legacy 化が単一方向でなく、層ごとに不均一に進行した証拠。

#### 5.9.2 Tensile (legacy snapshot)

代表例:

- `CHANGELOG.md`: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
- `Tensile/Source/lib/include/Tensile/AMDGPU.hpp`: `gfx900 = 900`、文字列解析・列挙が残存
- `Tensile/Source/lib/source/AMDGPU.cpp`: `gfx900` 分岐が残存

読み取り:

- retired 後でも arch table と changelog の双方で `gfx900` を保持しており、
  source-build / fallback 側の維持情報が消えていない。

#### 5.9.3 ROCR-Runtime (legacy snapshot)

代表例:

- `runtime/hsa-runtime/core/runtime/isa.cpp`
  - `gfx900`, `gfx900:xnack-`, `gfx900:xnack+` の ISA エントリが残存
- `rocrtst/Kernels/CMakeLists.txt`
  - test kernel build 対象に `gfx900`
- `rocrtst/README.md`
  - `gfx908;gfx900;...` 例と `gfx900` 実行ディレクトリ例が残存

読み取り:

- runtime 層でも `gfx900` は「削除済み」ではなく、少なくとも legacy snapshot では
  ISA 登録・テスト導線が残っている。

#### 5.9.4 ROCm fork vllm (legacy snapshot)

- README に retire 警告がある一方で、`gfx900` 参照は 0 行。
- これは Vega サポートの系譜ではなく、repo 再編（upstream 回帰）事例として扱うのが妥当。

#### 5.9.5 解釈

- `00_legacy-repos` は「すでに不要な死蔵」ではなく、
  **退役宣言と技術的痕跡が同居する forensic 層**として有用。
- 特に MIOpen / Tensile / ROCR-Runtime では、
  現行 monorepo 側で見える挙動の provenance を補助する一次証拠が残っている。

---

## 6. 今回見えた「事件」

### 事件1: support 拡張と support 後退が同じ ecosystem 内で共存していた

- 一方では `gfx900` を default build target に追加する component がある
- 別の時期・別の component では default build から外す

これは「ROCm 全体が同時に Vega を切った」のではなく、**各プロジェクトが別々の事情で扱いを変えていた**ことを示す。

### 事件2: 決定的な無効化理由が private issue に閉じている

- MIOpen の重要 commit は PR 番号 `#1328` を持つ
- しかし実際の根拠コメントは `llvm-project-private#389`

このため、公開 GitHub を見ても「何か問題があったらしい」ことは分かるが、**何が問題だったのかは追いきれない**。

### 事件3: build policy の後退が runtime 残存経路より先に起きている

- 既定 build からは外れる
- しかし runtime 側の fallback や lazy loading は残る

このズレが、「Vega はもうダメと言われるのに、実際には一部 workload はまだ動く」という今日の奇妙な状態を作っている。

### 事件4: public-facing な support 表記と solver 実態がずれている

- MLIR support hardware には `gfx900` が見える
- 実 solver は `gfx900` を reject する

これは documentation / code / runtime の三者が一致していない例であり、利用者が最も混乱しやすいパターン。

### 事件5: retired repo の案内先が stack の再編方向を露出している

- `00_legacy-repos/ROCR-Runtime/README.md`
  - retired を明記し、移行先として `ROCm/rocm-systems` を案内
- `00_legacy-repos/Tensile/README.md`
  - retired を明記し、移行先として `ROCm/rocm-libraries` を案内
- `00_legacy-repos/vllm/README.md`
  - retired を明記し、移行先として upstream `vllm-project/vllm` を案内

読み取り:

- これは `gfx900` 直接の事件ではないが、ROCm ecosystem が
  **repo 単位でも再編・統合・移管**されていることを示す。
- 少なくとも current ROCm を読むときは、現行 repo の中だけでなく
  「どの repo が retire され、どこへ吸収されたか」も歴史の一部として扱う必要がある。

補強証拠（commit provenance）:

- MIOpen README retire marker: `5123480a6` (`Migrating MIOpen`)
- ROCR-Runtime README retire marker: `ba56a24c` (`Deprecation README message`)
- Tensile README retire marker: `c5c24022` (`Updating readme to highlight deprecation`)
- ROCm/vllm README retire marker: `eb9d4de9eb` (`Deprecation notice`)

---

## 7. 現時点での読み筋

**事実として強く言えること**:

- `gfx900` は ROCm から一括で消えたのではない
- MIOpen MLIR iGEMM だけは 2021-12-22 に明示 disable された
- それでも 2022-10-05 時点の MIOpen では、`gfx900` 向け runtime workaround と docs 例が明示的に残っている
- その理由参照先は private LLVM issue で、公開調査には穴が残る
- その後も一部 component では build default が後退した
- しかし旧 solver / Tensile catalog / fallback は残った
- repo topology の面でも、standalone repo が `rocm-libraries` / `rocm-systems` / upstream へ寄る再編が起きている

**ここからの推測**:

- ROCm における Vega の扱いは、「完全サポート」から「完全削除」に直線的に移ったのではなく、**新しい最適化経路から先に脱落し、旧経路だけがしばらく残る**という legacy 化の典型パターンを辿った可能性が高い。
- 特に MIOpen の `gfx900` MLIR disable は、compiler backend 側の問題を public に十分説明できないまま product code 側で封じた事例に見える。

---

## 8. 既知の根拠一覧

- `ROCm/RELEASE.md`
  - `### HIPCC Perl scripts deprecation`
- `00_legacy-repos/ROCR-Runtime/README.md`
  - retired; use `ROCm/rocm-systems`
- `00_legacy-repos/Tensile/README.md`
  - retired; use `ROCm/rocm-libraries`
- `00_legacy-repos/vllm/README.md`
  - retired; use upstream `vllm-project/vllm`
- `00_legacy-repos/MIOpen/README.md`
  - retired; use `ROCm/rocm-libraries`
- `00_legacy-repos/MIOpen/src/target_properties.cpp`
  - `WORKAROUND_ISSUE_1204` (`gfx900` `sramecc-` misreport workaround)
- `00_legacy-repos/MIOpen/src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp`
  - `gfx900/gfx906` allow 条件
- `00_legacy-repos/MIOpen/src/solver/conv/conv_mlir_igemm_fwd.cpp`
  - `gfx900` reject 条件
- `00_legacy-repos/ROCR-Runtime/runtime/hsa-runtime/core/runtime/isa.cpp`
  - `gfx900`, `gfx900:xnack-`, `gfx900:xnack+` ISA entries
- `00_legacy-repos/Tensile/CHANGELOG.md`
  - `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
- `00_legacy-repos/Tensile/Tensile/Source/lib/include/Tensile/AMDGPU.hpp`
  - `gfx900` enum / parser mapping
- `ROCm/tools/autotag/templates/highlights/6.0.0.md`
  - `GPU_TARGETS` accepted in addition to `AMDGPU_TARGETS`
- `ROCm/tools/autotag/templates/highlights/6.2.0.md`
  - `Math libraries default to Clang instead of HIPCC`
- `Tensile/CHANGELOG.md`
  - `Tensile 4.36.0 for ROCm 5.5.0`: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
- `MIOpen`
  - PR `#166`: `[dynamic-igemm] add v4r1 dynamic kernel and solver, fwd fp32`
  - PR `#272`: `[igemm_dynamic] v4r1 bwd dynamic kernel`
  - issue `#999` / PR `#1001`: Vega20 `ConvAsmImplicitGemmV4R1DynamicWrw` validation fail と修正
  - PR `#1968`: `[Vega20] Workaround for 25% winograd performance drop`
  - PR `#1328`: ROCm 5.1 milestone, `MIOPEN_TEST_GFX900/GFX906` 分離, `GFX900_DISABLED` 導入
  - commit `2407d2f556c7635de3f4b3f009681bdd92ba82e2`
  - subject: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
  - comment reference: `llvm-project-private#389`
  - commit `e5c6ce1b61233392ca8660f426fd018709c395cc`
  - subject: `v2.18.0 release notes`
  - `target_properties.cpp`: `WORKAROUND_ISSUE_1204` (`gfx900` `sramecc-` misreport workaround)
  - `doc/src/embed.md`: `gfx906_60;gfx900_56`, `-DMIOPEN_EMBED_DB=gfx900_56`
  - `doc/src/find_and_immediate.md`: `gfx900 with 64 CUs`, `gfx900 with 56 CUs`
  - commit `b0f912e5244b`
  - private issue 参照の URL org-name 更新
- `Tensile`
  - PR `#1595`: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
  - PR `#1862`: `Use fallback libraries for archs without optimized logic`
- 現行ソース
  - ASM implicit GEMM の `gfx900` 明示許可
  - MLIR iGEMM の `gfx900` 明示除外
  - rocBLAS/Tensile の `gfx900` lazy loading
  - Tensile / CK の dot4 非対応 fallback

---

## 9. 未回収の論点

ローカル clone だけでは、次は確定できていない。

- `llvm-project-private#389` の issue 本文
- 当時の regression 報告や議論の温度感
- 他 component で `gfx900` が default build から外れた時の詳細な議論

このため、次段のネットワーク付き調査では次をやる価値がある。

- public PR / issue の timeline 回収（MIOpen/Tensile/rocBLAS 全体）
- `#1328` の review threads 全文回収（現在は issue body + metadata まで）
- `gfx900` / `vega` / `non-xdlops` / `llvm-project-private#389` の cross-reference 探索

---

## 10. 現時点の暫定結論

ROCm の GitHub 履歴から見える Vega / `gfx900` の変遷は、「古い GPU が静かに消えた」というより、**個別 component ごとに support policy がずれたまま、一部経路は private issue を理由に止められ、一部経路は legacy / fallback path として残存し続けた**というものだった。

このズレが、現在の Vega 調査で観測される「MLIR は死んでいるが ASM/Tensile/fallback は残る」という断片的な生存状態を、そのまま説明している。

したがって、Vega/gfx900 の現在の状態は「非対応」か「対応」かの二値ではなく、コンポーネントごとの歴史的判断が積み重なった結果としての、段階的 legacy 化の産物とみなすのが最も自然である。
