# Vega/gfx900 調査 ワークログ

更新日: 2026-03-15
対象: `/home/limonene/ROCm-project/tank/lab_notebook/notes/vega_investigations/`

## 現状サマリ

- gfx900 の MLIR iGEMM 除外は、AMD 社員による明示コミット `2407d2f`（2021-12-22）で導入されたことを確認済み。
- `IsMlirSupportedHardware()` には gfx900 が含まれる一方、`ConvMlirIgemmFwd/Bwd/Wrw::IsApplicable()` 側で後段除外される二重構造を確認済み。
- MLIR 強制実行では `boost::optional::get()` assertion crash まで再現し、MLIR 経路が gfx900 で実用不能であることを実機で確認済み。
- MIOpen debug build は CIFS を避けて WD-Black NVMe 上で成功し、gfx900 向け最小構成（MLIR/CK/AI機能OFF）のビルド導線を確立済み。
- 2026-03-15 以降、AMD Repository の日常運用正本を WD-Black (`/home/limonene/ROCm-project/WD-Black/ROCm-repos`) に固定し、CIFS 側は取得元として扱う方針に変更。
- `ROCm/CHANGELOG` と MIOpen commit history から、`gfx900` が一括削除ではなく「追加 -> private issue 起因 disable -> 既定 build からの後退 -> legacy/fallback 残存」という層状変遷を辿ったことを整理済み。
- 現時点の主な未解決事項は、`MiirIsConfigApplicable` を含む MLIR ライブラリ内部制約の確認と、`gfx900` 関連変更の provenance map 拡張。

---

このログは「何をやったか・何を見たか・何がわかったか」を時系列で記録する。
推論・仮説は `hypothesis.md`、確定した事実は `facts.md` に分離している。
知識の集積先は `vega-rocm.md`（推論経路本体）。ここは「作業の流れ」を残す場所。

### ステータスラベル定義

| ラベル | 意味 |
|---|---|
| **完了** | そのフェーズの主要問いに答えた |
| **完了（部分）** | 手段は成立したが、依存待ちまたは次段あり |
| **未完了** | まだ主要観測なし |

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
| detached 起動（Ninja化） | `Ninja` | configure/generate までは到達したが、workspace 側 `tmp` を build root にしたため `llvm-min-tblgen: Permission denied (code=126)` で停止 |
| 現行 detached 起動 | `Ninja` + build root=`/tmp` | noexec 回避のため build root を `/tmp` に変更して再起動。現在 build 進行中。 |

**依存追加対応**

- `pybind11`: `sudo pacman -S pybind11` → configure で `Found pybind11` を確認

**追加で判明したこと**

- 調査ワークスペース配下の `tmp/` は noexec 相当で、rocMLIR/LLVM ビルド中に生成される補助実行ファイル（例: `llvm-min-tblgen`）を実行できない
- そのため detached 起動スクリプト `tools/start_rocmlir_build_detached.sh` は、既定 generator を `Ninja`、既定 build root を `/tmp` に変更した

**現状**: `/tmp/rocmlir-build-detached-20260313_172420` で rocMLIR build が進行中。workspace 側 prefix `tmp/rocmlir-prefix-detached-20260313_172420/` に `rocMLIRConfig.cmake` が生成されたら、待機中の監視ジョブから MIOpen debug ビルドへ自動接続する構成に切り替え済み。

---

### [完了] CIFS 問題の解決 + NVMe ローカルビルド成功（2026-03-14）

**問題**

前日からの MIOpen cmake configure が 12時間以上経過しても完了しない。
`ps aux` で確認したところ、PID 653547 (cmake) が State: D（uninterruptible sleep）で CIFS I/O 待ちに張り付いていた。

**根本原因**

調査ソースが CIFS マウント (`//100.67.180.73/tank`) 上にあったため、cmake の大量の `stat()` / `read()` が CIFS を経由し、D-state I/O wait が頻発していた。

**対処**

WD-Black NVMe (btrfs, `/home/limonene/ROCm-project/WD-Black/`) に MIOpen ソースを新規 clone:

```bash
cd /home/limonene/ROCm-project/WD-Black
git clone --depth 1 --branch rocm-7.2.0 https://github.com/ROCm/MIOpen.git miopen-src
```

> **劇的改善**: cmake configure が **7.5秒** で完了（CIFS では 12時間以上未完了）。

**ビルド設定と解決したブロッカー一覧**

| # | ブロッカー | 原因 | 対処 |
|---|---|---|---|
| 1 | CIFS 上で cmake configure 12h+ ハング | CIFS I/O の D-state | WD-Black NVMe にソース clone |
| 2 | rocMLIR prefix 消滅 | `/tmp` 上の前日ビルド成果物が消えていた | `-DMIOPEN_USE_MLIR=Off` で回避 |
| 3 | `--offload-arch=gfx900` がGCCで未認識 | システムGCCはHIPコンパイル不可 | `-DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++` |
| 4 | CK `v_fmac_f32` がgfx900に存在しない | gfx906+ 専用命令 | `-DMIOPEN_USE_COMPOSABLEKERNEL=Off` |
| 5 | `half_float::detail::expr` 未定義 | half 2.2.x ではこの型が削除されている | `test/verify.hpp:198` をパッチ |

**最終 cmake 構成**

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

**ビルド結果**

- `ninja MIOpen`: 成功（libMIOpen.so ビルド完了）
- `ninja MIOpenDriver`: 成功
- `ninja install`: 成功
- 所要時間: configure 9.6秒 + ビルド数分
- ビルドディレクトリ: `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-build-20260314_135541/`
- インストール先: `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-prefix-20260314_135541/`

**test/verify.hpp パッチ内容**

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

**動作確認**

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

**INT8 テスト**

```bash
MIOPEN_ENABLE_LOGGING=1 MIOPEN_LOG_LEVEL=6 \
  /opt/rocm/bin/MIOpenDriver convint8 \
  -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1 2>&1 | tee mlir_force_test.log
```

結果:
```
CompileSolution: ConvMlirIgemmFwd
GetInvoker: ConvMlirIgemmFwd
Perf Db: record not found
MIOpen(HIP): Warning ... boost::optional::get() Assertion ... terminated
```

**FP32 テスト**

```bash
MIOPEN_ENABLE_LOGGING=1 MIOPEN_LOG_LEVEL=6 \
  /opt/rocm/bin/MIOpenDriver conv \
  -n 1 -c 3 -H 32 -W 32 -k 16 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1 2>&1 | tee mlir_force_fp32.log
```

結果: 同一パターンの `boost::optional::get()` assert クラッシュ。

**わかったこと**

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

**完了した後続アクション（2026-03-15）**

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

**何をやったか**

- `MIOpen` の `git blame` / commit metadata を再確認
- `ROCm/CHANGELOG.md` の component ごとの `gfx900` 記述を release block 単位で整理
- 現行ソースに残る `gfx900` 経路と、過去の build policy 変更を突き合わせた

**わかったこと**

- `MIOpen` の MLIR iGEMM `gfx900` 除外は、AMD 社員の commit `2407d2f`（2021-12-22）で意図的に導入された
- 根拠参照先は `llvm-project-private#389` であり、公開 GitHub だけでは理由本文に到達できない
- `ROCm 5.5.0` block の `Tensile (4.36.0)`、`ROCm 6.2.0` block の `rocSOLVER (3.26.0)` では追加系記述がある一方、
  `ROCm 7.0.0` block の `hipCUB (4.0.0)` では `gfx900` が既定 build 対象から外れている
- したがって、ROCm における `gfx900` は「ある日一括で死んだ」のではなく、component ごとに時間差をもって legacy 化したと読むのが自然

**成果物**

- `rocm-github-investigate.md`

---

## 作成した成果物ファイル一覧

### ドキュメント

| ファイル | 状態 | 内容 |
|---|---|---|
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
|---|---|
| `../../../WD-Black/mlir_force_test.log` | INT8 MLIR iGEMM 強制実行ログ（boost::optional crash） |
| `../../../WD-Black/mlir_force_fp32.log` | FP32 MLIR iGEMM 強制実行ログ（同上） |

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
|---|---|
| LD_PRELOAD での MIIR C API フック | `miir*` C シンボルが `libMIOpen.so` から直接見えないため不成立 |
| `find` / 広範囲 Glob での全ファイル探索 | タイムアウト頻発。直接パス指定・`ls` 段階アプローチに切り替え |
| MIOpen フォークによる MLIR gfx900 対応 | LLVM コンパイラレベルの問題のため MIOpen 側だけでは修正不可 |
