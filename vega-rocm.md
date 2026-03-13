# Vega/gfx900 推論経路・DP4A代替経路 調査メモ（生コード根拠）

更新日: 2026-03-13
対象: docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo 配下

## 1. 結論サマリ

- gfx900（Vega10）向けの推論系/畳み込み系経路は、MIOpenとrocBLAS/Tensileに明確に残存している。
- MIOpenでは gfx900 を明示許可するASM implicit GEMM系ソルバが残っている一方、MLIR iGEMMは gfx900 を明示的に除外している。
- DP4A相当（v_dot4_i32_i8）が使えない場合の代替計算（要素積和ループ）実装が存在し、DP4Aエミュレーション相当の挙動候補として有力。
- TensileのISA能力テーブルでも gfx900 相当 (9,0,0) は dot4系capabilityがFalseになっており、旧世代経路に落ちる設計が確認できる。

## 2. 主要な計算経路（今回の主眼）

### 2.1 MIOpen: gfx900明示で有効化されるASM implicit GEMM経路

- FWD: miopen/src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp:293
	- `StartsWith(device_name, "gfx900") || StartsWith(device_name, "gfx906")` のみ通す。
- FWD 1x1: miopen/src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp:343
	- 同様に gfx900/gfx906 に限定。
- BWD: miopen/src/solver/conv/conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp:142
	- 同様に gfx900/gfx906 に限定。
- WRW: miopen/src/solver/conv/conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp:306
	- 同様に gfx900/gfx906 に限定。

観測ポイント:
- これらは「旧世代向け専用に近い分岐」が今も生きていることを示す。
- 推論時のConv実行で、条件次第で新しめの経路ではなくASM v4r1 dynamic系が選択される可能性がある。

### 2.2 MIOpen: MLIR iGEMMはgfx900を除外（=別経路へフォールバック）

- FWD: miopen/src/solver/conv/conv_mlir_igemm_fwd.cpp:188
	- `if(StartsWith(device_name, "gfx900")) return false;`
- BWD: miopen/src/solver/conv/conv_mlir_igemm_bwd.cpp:68
	- 同様に gfx900 を除外。
- WRW: miopen/src/solver/conv/conv_mlir_igemm_wrw.cpp:69
	- 同様に gfx900 を除外。

観測ポイント:
- gfx900ではMLIR iGEMMが候補から外れ、他ソルバ（ASM/DLOPS/非MLIR）が相対的に使われやすくなる。

#### 2.2.1 除外の根拠コミット（git blame 確定）code_verified

- 除外コミット: `2407d2f556c7635de3f4b3f009681bdd92ba82e2`
- 日付: 2021-12-22 / 作者: Zhuoran Yin (zhuoryin@amd.com)
- コミットメッセージ: `[MLIR] Disable gfx900 from non-xdlops solver (#1328)`
- FWD/BWD/WRW 全3ファイルが同一コミットで同時に除外された。

各ファイルに付いているコメント（元コミット時点から存在）:
```cpp
// Refer to https://github.com/ROCmSoftwarePlatform/llvm-project-private/issues/389
```
（2023年の URL修正コミット b0f912e が `ROCmSoftwarePlatform` → `ROCm` に組織名を書き換えたのみ）

**重要**: `#389` は `llvm-project-private`（AMDの非公開LLVMリポジトリ）のissueであり、
公開リポジトリ（MIOpen #389、rocMLIR #389）とは**全くの別物**。
内容は外部からは読めないが、MLIR コンパイラバックエンド側の gfx900 制約と推測される。

次の掘り下げ候補:
- MIOpen 本体の PR #1328 のレビューコメント（GitHub）に追加情報の可能性
- 公開版 `llvm-project` での gfx900 / MLIR 関連 issue・コミットとの照合
- `MiirIsConfigApplicable` 内部の制約確認（ライブラリ側に直接制限がないか）

### 2.3 MIOpenソルバ登録上の残存経路

- miopen/src/solver.cpp:546
	- `ConvCkIgemmFwdV6r1DlopsNchw` が登録。
- miopen/src/solver.cpp:569
	- `ConvAsmImplicitGemmGTCDynamicFwdDlopsNCHWC` が登録。
- miopen/src/solver.cpp:516-520 近傍
	- MLIR iGEMM群も登録されるが、上記の通り gfx900 側では適用外判定が入る。

観測ポイント:
- レジストリ上は新旧複数経路が共存しており、gfx900では適用条件により旧寄り経路へ流れる設計。

### 2.4 rocBLAS/Tensile: gfx900向けLazyLoading経路

- rocblas/library/src/tensile_host.cpp:238-240
	- `deviceString.find("gfx900")` で `Tensile::LazyLoadingInit::gfx900` を返す。

観測ポイント:
- GEMM系推論（特にINT8/混合精度）で、Tensile側のgfx900向けライブラリ/分岐が依然として実運用候補。

## 3. DP4Aエミュレーション証跡の候補

### 3.1 直接的な代替実装（有力）

- composablekernel/include/ck/utility/inner_product.hpp:179 以降
	- `inner_product<int8x4_t, int8x4_t, int32_t>` で、
		- dot命令が使える場合: `v_dot4_i32_i8` / `__builtin_amdgcn_sdot4`
		- dot命令が使えない場合: 4要素を逐次積和するフォールバック実装

解釈:
- これは「DP4A（dot4相当）が弱い/ない環境で結果互換を保つためのソフトウェア代替計算」に相当する挙動。

### 3.2 gfx900でdot4 capabilityが無効な証跡

- shared/tensile/Tensile/AsmCaps.py:128 以降（ISA (9,0,0)）
	- `VOP3v_dot4_i32_i8: False`
	- `v_dot4_i32_i8: False`
	- `v_dot4c_i32_i8: False`

- shared/tensile/Tensile/Common.py:2065-2067
	- `v_dot4_i32_i8` / `v_dot4c_i32_i8` / `VOP3v_dot4_i32_i8` をアセンブラで判定してcapability化。

解釈:
- Tensile側でも、ISA能力でdot4が立たない構成では別実装（非dot4）へ落ちる前提が明確。

### 3.3 legacy CK設定での世代差分

- miopen/src/legacy_composable_kernel/composable_kernel/include/utility/config.hpp:50
	- gfx803/gfx900 は `CK_USE_AMD_V_MAC_F32`。
- 同ファイル:53-58
	- `CK_USE_AMD_V_DOT4_I32_I8` は gfx906以降側で有効化。
- 同ファイル:88-90
	- `CK_USE_AMD_XDLOPS` 既定値は 0。

解釈:
- legacy CKのコンパイル設定上、gfx900はdot4/xdlops系の新しめ命令経路に乗りづらく、非dot4/旧命令側に寄る。

## 4. gfx900識別の根拠

- miopen/src/target_properties.cpp:51-52
	- `"Vega10" -> "gfx900"`, `"gfx901" -> "gfx900"`

解釈:
- Vega10系が実際にgfx900経路へ正規化される。

## 5. 今回の「残っている推論path」候補（優先度順）

1) MIOpen ASM implicit GEMM v4r1 dynamic（FWD/BWD/WRW）
- 根拠: conv_asm_implicit_gemm_*_v4r1_dynamic.cpp の gfx900/gfx906 明示条件。

2) MIOpen DLOPS系（ConvCkIgemmFwdV6r1DlopsNchw, ConvAsmImplicitGemmGTCDynamicFwdDlopsNCHWC）
- 根拠: solver.cpp の登録経路。

3) rocBLAS->Tensile の gfx900 lazy loading 経路
- 根拠: rocblas tensile_host.cpp の getLazyLoadingArch。

4) DP4A非対応時の代替積和実装（DP4Aエミュレーション候補）
- 根拠: composablekernel inner_product.hpp の dot4不在フォールバック、Tensile AsmCapsのdot4 false。

## 6. 追加で確認したい点（次アクション候補）

- 実機ログでのソルバ選択確認
	- MIOpenログで実際に `ConvAsmImplicitGemmV4R1Dynamic*` や `Dlops` が選ばれているか。
- gfx900でのINT8推論時に、dot4命令が実際に生成されずフォールバックへ入るケースの再現。
- 同一モデルを gfx900 と gfx90a 以上で比較し、経路差（MLIR/XDLOPS可否、速度、安定性）を定量化。

## 7. 実機での再現手順（経路生存確認つき）

以下は「このメモの証跡を手がかりに、実機で推論PATHが実際にどう流れるか」を確認するための手順。

### 7.1 事前固定（環境差の吸収）

1) 実行環境を記録

```bash
date
hostname
uname -a
/opt/rocm/bin/rocminfo | rg -n "Name:|gfx"
/opt/rocm/bin/rocm-smi --showproductname --showperflevel --showclocks
```

2) キャッシュ影響を減らす（初回/比較時）

```bash
rm -rf ~/.cache/miopen/* 2>/dev/null || true
rm -rf ~/.cache/rocblas/* 2>/dev/null || true
```

3) ログ保存先を固定

```bash
mkdir -p ~/vega_path_check_logs
```

### 7.2 MIOpenで「どのソルバ経路が選ばれたか」を直接確認

目的:
- gfx900で ASM implicit GEMM / DLOPS / (除外されるはずの)MLIR のどれが選択されるかをログで確認する。

実行例（ベースライン）:

```bash
export MIOPEN_ENABLE_LOGGING=1
export MIOPEN_ENABLE_LOGGING_CMD=1
export MIOPEN_LOG_LEVEL=6

# 例: 2D Conv FWD (NCHW, FP32)
miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1 \
	2>&1 | tee ~/vega_path_check_logs/miopen_conv_fp32_baseline.log
```

確認ポイント:
- ログ中の solver 名に以下が出るか
	- `ConvAsmImplicitGemmV4R1Dynamic*`
	- `ConvCkIgemmFwdV6r1DlopsNchw`
	- `ConvAsmImplicitGemmGTCDynamicFwdDlopsNCHWC`
	- `ConvMlirIgemm*`（gfx900なら通常は選ばれない想定）

抽出例:

```bash
rg -n "ConvAsmImplicitGemm|ConvCkIgemm|ConvMlirIgemm|Dlops|Xdlops" ~/vega_path_check_logs/miopen_conv_fp32_baseline.log
```

### 7.3 経路ごとの生存確認提案（項目別）

#### A) ASM implicit GEMM v4r1 dynamic 生存確認

方法:
- FP32/NCHW/2D/Group=1/packed 条件で複数shapeを流し、solver名に `ConvAsmImplicitGemmV4R1Dynamic*` が現れるか確認。
- 1x1 と 3x3 の両方を試す（別分岐があるため）。

実行例:

```bash
# 1x1
miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 -F 1 -t 1 \
	2>&1 | tee ~/vega_path_check_logs/miopen_conv_fp32_1x1.log

# 3x3
miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1 \
	2>&1 | tee ~/vega_path_check_logs/miopen_conv_fp32_3x3.log
```

判定:
- どちらかで `ConvAsmImplicitGemmV4R1Dynamic` 系が選択されれば「経路生存」。

#### B) MLIR iGEMM の gfx900 除外確認

方法:
- 同条件でMLIR系 solver 名が出ないことを確認。
- 比較として gfx90a 以上環境があるなら同じshapeで `ConvMlirIgemm*` の出現有無を比較。

判定:
- gfx900で `ConvMlirIgemm*` が選択されなければ、コード上の除外条件と整合。

#### C) DLOPS系経路の生存確認

方法:
- NCHW/NCHWC、INT8/FP32 の複数ケースを流し、`Dlops` を含む solver/kernel 名を探索。

抽出例:

```bash
rg -n "Dlops|dlops|ConvCkIgemmFwdV6r1DlopsNchw|GTCDynamicFwdDlopsNCHWC" ~/vega_path_check_logs/*.log
```

判定:
- DLOPS系名称が1つでも選択されれば生存。

#### D) rocBLAS/Tensile 側 gfx900 経路生存確認

方法:
- GEMMベンチでrocBLASログを有効化し、Tensile実行痕跡を確認。

実行例:

```bash
export ROCBLAS_LAYER=4
export ROCBLAS_LOG_TRACE_PATH=~/vega_path_check_logs/rocblas_trace.log

rocblas-bench -f gemm_ex --transposeA N --transposeB N -m 1024 -n 1024 -k 1024 \
	--a_type i8_r --b_type i8_r --c_type i32_r --d_type i32_r --compute_type i32_r \
	2>&1 | tee ~/vega_path_check_logs/rocblas_gemm_int8.log
```

判定:
- Tensile solution/kernel実行痕跡が取得できれば、gfx900向けlazy loading経路が実運用で生きている可能性が高い。

### 7.4 DP4Aエミュレーション候補の実機検証

目的:
- `v_dot4_i32_i8` が使われるケース/使われないケースを実際の生成コードで判定。

方法1: 生成バイナリ逆アセンブル（推奨）

1) 実行でHSACO生成
2) 対象HSACOを逆アセンブル
3) dot4命令有無をgrep

```bash
# 実行後に生成された hsaco を探索（候補）
find ~/.cache -type f \( -name "*.hsaco" -o -name "*.co" \) | head -n 50

# 例: 逆アセンブル
llvm-objdump -d <target.hsaco> > ~/vega_path_check_logs/target_hsaco.s

# dot4命令の有無を確認
rg -n "v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4" ~/vega_path_check_logs/target_hsaco.s
```

判定:
- dot4命令が見えない一方でINT8演算カーネルが動いているなら、代替積和経路に落ちている可能性が高い。

方法2: カーネル名と性能の相関で推定

- `rocprofv3` でカーネル名・実行時間を取得し、dot4系を使う世代（比較機）との差分を見る。

```bash
rocprofv3 --hip-trace --kernel-trace --output-dir ~/vega_path_check_logs/rocprof_out -- \
	miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1
```

## 8. 密結合で「複数経路をまとめて試す」包括手順

実務では、単一フラグで経路固定できないことが多いため、以下のマトリクス実行が有効。

### 8.1 テストマトリクス（最小）

- データ型: FP32, INT8
- レイアウト: NCHW, NCHWC
- カーネル: 1x1, 3x3
- 方向: FWD, BWD, WRW
- バッチ: 1, 32

各ケースで記録するもの:
- 選択solver名
- 実行kernel名
- 実行時間
- HSACO内dot4命令有無

### 8.2 1ケース1ログの実行テンプレート

```bash
CASE_ID=fp32_nchw_3x3_fwd_n32

MIOPEN_ENABLE_LOGGING=1 MIOPEN_ENABLE_LOGGING_CMD=1 MIOPEN_LOG_LEVEL=6 \
miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1 \
	2>&1 | tee ~/vega_path_check_logs/${CASE_ID}.log

rg -n "ConvAsmImplicitGemm|ConvCkIgemm|ConvMlirIgemm|Dlops|Xdlops" ~/vega_path_check_logs/${CASE_ID}.log \
	| tee ~/vega_path_check_logs/${CASE_ID}.solver_extract.log
```

## 9. 成功判定の基準（この調査向け）

- 経路生存: 対応solver名/カーネル名が1回でも選択される。
- 経路非生存: 条件を変えても該当solver名が一切現れない。
- DP4Aエミュレーション候補成立:
	- INT8推論は成立している
	- かつHSACOにdot4命令が見えない（またはdot4非対応capability世代）
	- かつ代替積和系の挙動/性能傾向が観測される

## 10. 追記メモ（運用上の注意）

- 初回実行はコンパイル時間が混ざるため、各ケース最低2回実行し2回目以降で比較する。
- 熱・クロック影響を減らすため、連続実験時は `rocm-smi` で状態を併記する。
- solver名の表記ゆれ（大文字小文字、末尾サフィックス差）を吸収するため、grepは部分一致で行う。

## 11. フォールバック経路トレース（ファイル/行番号つき）

この章は「どこで候補が弾かれ、どの候補群へ遷移するか」をソース上で追えるようにしたトレース。

### 11.1 MIOpen 全体の候補フィルタ（共通）

1) ImplicitGEMM finder有効化
- miopen/src/conv/solver_finders.cpp:98
	- `!parameters.use_winograd_only && !env::disabled(MIOPEN_DEBUG_CONV_IMPLICIT_GEMM)`

2) ImplicitGEMM候補群へ分岐
- miopen/src/conv/solver_finders.cpp:109-110
	- Forward/BwdData は `FindAllImplicitGemmSolutions(...)`
	- BwdWrW は `FindImplicitGemmWrWAllSolutions(...)`

3) 候補ごとの適用可否チェックで不適用をスキップ
- miopen/src/include/miopen/find_solution.hpp:326
- miopen/src/include/miopen/find_solution.hpp:381
- miopen/src/include/miopen/find_solution.hpp:451
	- `else if(!solver.IsApplicable(ctx, problem))` でスキップ
- miopen/src/problem.cpp:573,625
	- `if(!solver->IsApplicable(ctx, problem_description))`
- miopen/src/problem.cpp:575,627
	- `"Not applicable"` ログ出力

4) 先頭の適用可能solverを実行（単純実行経路）
- miopen/src/include/miopen/find_solution.hpp:467
	- `ExecutePrimitive(...)`
- miopen/src/include/miopen/find_solution.hpp:481
	- `SearchForSolutions(..., 1, ...)`

要点:
- 「明示的なif-elseフォールバック」ではなく、候補列挙 + IsApplicableで不適用を落として次候補へ進む方式。

### 11.2 gfx900でMLIR iGEMMが落ちるトレース

1) MLIR候補は登録されている
- miopen/src/solver.cpp:508-510
	- `ConvMlirIgemmFwd/Bwd/WrW` をレジストリ登録

2) ただし gfx900 で `IsApplicable` が false
- miopen/src/solver/conv/conv_mlir_igemm_fwd.cpp:188
- miopen/src/solver/conv/conv_mlir_igemm_bwd.cpp:68
- miopen/src/solver/conv/conv_mlir_igemm_wrw.cpp:69
	- `if(StartsWith(device_name, "gfx900")) return false;`

3) 共通フィルタで「Not applicable」として除外
- miopen/src/include/miopen/find_solution.hpp:326/381/451
- miopen/src/problem.cpp:573/625

4) 次候補（例: ASM/DLOPS系）へ移行
- 候補例（登録）
	- miopen/src/solver.cpp:546 `ConvCkIgemmFwdV6r1DlopsNchw`
	- miopen/src/solver.cpp:569 `ConvAsmImplicitGemmGTCDynamicFwdDlopsNCHWC`

### 11.3 gfx900でASM v4r1 dynamicが拾われるトレース

1) ASM v4r1 dynamic側の適用条件
- FWD: miopen/src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp:293
- FWD 1x1: miopen/src/solver/conv/conv_asm_implicit_gemm_v4r1_dynamic.cpp:343
- BWD: miopen/src/solver/conv/conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp:142
- WRW: miopen/src/solver/conv/conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp:306
	- いずれも `StartsWith(device_name, "gfx900") || StartsWith(device_name, "gfx906")` を要求

2) MLIRがgfx900で落ちた後、上記が条件一致すれば採用候補として残る
- 実際の採用は `FindSolution` 成否と性能DB/探索結果次第
- 不成立時はさらに次候補へ進む（11.1の共通ループ）

### 11.4 XDLOPS非対応/エミュレート設定のトレース

1) XDLOPSサポート判定
- miopen/src/include/miopen/solver/implicitgemm_util.hpp:101-105
	- 既定の `is_xdlops_supported` は `gfx908/gfx90a/gfx942/gfx950`
	- それ以外（gfx900含む）は通常 false

2) 強制エミュレート分岐
- miopen/src/include/miopen/solver/implicitgemm_util.hpp:95
	- `MIOPEN_DEBUG_CONV_IMPLICIT_GEMM_XDLOPS_EMULATE` が有効なら true を返す

トレース解釈:
- gfx900では既定でXDLOPS経路に入りにくく、非XDLOPS（ASM/DLOPS等）へ寄る。

### 11.5 CK内部のDP4A相当フォールバックトレース

1) int8x4内積の分岐本体
- composablekernel/include/ck/utility/inner_product.hpp:179
	- `inner_product<int8x4_t, int8x4_t, int32_t>`

2) dot4命令を使う分岐
- 同:181 `#if defined(CK_USE_AMD_V_DOT4_I32_I8)`
- 同:193 `__builtin_amdgcn_sdot4(...)`

3) GFX11向け分岐
- 同:195 `#elif defined(CK_USE_AMD_V_DOT4_I32_I8_GFX11)`

4) 最終フォールバック（逐次積和）
- 同:201 `static_for<0, 4, 1>{}...` で4要素を手計算

トレース解釈:
- dot4系マクロが立たないビルド/世代では、計算結果互換のソフトウェア寄り経路へ落ちる。

### 11.6 legacy CKマクロによる世代別ゲート

- miopen/src/legacy_composable_kernel/composable_kernel/include/utility/config.hpp:51
	- gfx803/gfx900 側は `CK_USE_AMD_V_MAC_F32`
- 同:59
	- `CK_USE_AMD_V_DOT4_I32_I8`（条件分岐内）
- 同:86-87
	- `CK_USE_AMD_XDLOPS` 既定 `0`

補足:
- このマクロ設計が、旧世代でdot4/xdlopsに乗りにくいコンパイル分岐を作る。

### 11.7 Tensile能力表でのdot4不在トレース（gfx900相当）

1) gfx900相当ISAエントリ
- shared/tensile/Tensile/AsmCaps.py:128 `(9, 0, 0)`

2) dot4 capability
- 同:155 `VOP3v_dot4_i32_i8: False`
- 同:158 `v_dot4_i32_i8: False`
- 同:159 `v_dot4c_i32_i8: False`

トレース解釈:
- Tensile側でもgfx900相当ではdot4系命令能力を立てず、別実装へ落ちる前提。

### 11.8 rocBLAS -> Tensile の gfx900マッピングトレース

- rocblas/library/src/tensile_host.cpp:232
	- `getLazyLoadingArch(...)`
- 同:238
	- `deviceString.find("gfx900")`
- 同:240
	- `return Tensile::LazyLoadingInit::gfx900;`
- 同:866
	- 実使用側で `getLazyLoadingArch(deviceString)` を参照

トレース解釈:
- 実機がgfx900として認識されると、Tensileのgfx900経路へ明示マップされる。

### 11.9 実機ログとソーストレースを突き合わせる最小手順

1) `MIOPEN_ENABLE_LOGGING=1` + `MIOPEN_LOG_LEVEL=6` で実行
2) ログから `Not applicable` と solver名を抽出
3) 上記 11.1-11.8 の行番号に対応づける

抽出例:

```bash
rg -n "Not applicable|ConvMlirIgemm|ConvAsmImplicitGemm|Dlops|Xdlops" ~/vega_path_check_logs/*.log
```

これで「どの条件で落ちたか（コード）」と「実際にどこへ流れたか（ログ）」を1対1で追跡できる。

## 12. フォールバック判定チェックリスト（ログ行 <-> ソース行 対応テンプレート）

以下を1ケースごとに埋める。目的は「観測ログ」と「分岐コード」を1行単位で対応づけること。

### 12.1 ケース実行前チェック

- [ ] GPU識別を記録した（`rocminfo` で `gfx900` を確認）
- [ ] 実行条件を固定した（dtype/layout/shape/direction/batch）
- [ ] キャッシュ条件を記録した（削除有無、1回目か2回目以降か）
- [ ] ログ保存先をケースIDで分けた（例: `~/vega_path_check_logs/<CASE_ID>.log`）

### 12.2 ログ採取チェック

- [ ] `MIOPEN_ENABLE_LOGGING=1` を有効化した
- [ ] `MIOPEN_LOG_LEVEL=6` を有効化した
- [ ] 実行ログ全文を保存した
- [ ] solver抽出ログを別ファイルで保存した

抽出コマンド例:

```bash
CASE_ID=fp32_nchw_3x3_fwd_n32
LOG=~/vega_path_check_logs/${CASE_ID}.log

rg -n "Not applicable|ConvMlirIgemm|ConvAsmImplicitGemm|ConvCkIgemm|Dlops|Xdlops|Skipped \(non-dynamic\)" "$LOG" \
	| tee ~/vega_path_check_logs/${CASE_ID}.trace_extract.log
```

### 12.3 ログ行 -> ソース行 対応表（記入テンプレート）

この表をケースごとに埋める。

| 観測ログ（抜粋） | ログ行番号 | 判定 | 対応ソース | ソース行 | 次に試された候補 | 備考 |
|---|---:|---|---|---:|---|---|
| `ConvMlirIgemmFwd: Not applicable` |  | MLIR除外 | `conv_mlir_igemm_fwd.cpp` | 188 | `ConvAsmImplicitGemm...` or `Dlops...` | gfx900除外 |
| `...: Not applicable` |  | gfx900/条件不一致 | `conv_asm_implicit_gemm_v4r1_dynamic.cpp` | 293 or 343 | 次solver | shape条件も確認 |
| `...: Not applicable` |  | BWD不一致 | `conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp` | 142 | 次solver |  |
| `...: Not applicable` |  | WRW不一致 | `conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp` | 306 | 次solver |  |
| `Skipped (non-dynamic)` |  | 動的限定で除外 | `find_solution.hpp` | 324 or 449 | 次solver | dynamic only設定時 |

### 12.4 代表トレース辞書（参照先早見）

- 共通フィルタ
	- `find_solution.hpp`: 326, 381, 451
	- `problem.cpp`: 573, 575, 625, 627
- ImplicitGEMM finder
	- `solver_finders.cpp`: 98, 109, 110
- MLIR gfx900除外
	- `conv_mlir_igemm_fwd.cpp`: 188
	- `conv_mlir_igemm_bwd.cpp`: 68
	- `conv_mlir_igemm_wrw.cpp`: 69
- ASM v4r1 dynamic gfx900/906条件
	- `conv_asm_implicit_gemm_v4r1_dynamic.cpp`: 293, 343
	- `conv_asm_implicit_gemm_bwd_v4r1_dynamic.cpp`: 142
	- `conv_asm_implicit_gemm_wrw_v4r1_dynamic.cpp`: 306
- XDLOPS支援/エミュレート分岐
	- `implicitgemm_util.hpp`: 95, 101-105
- DP4A相当フォールバック
	- `composablekernel/include/ck/utility/inner_product.hpp`: 179, 181, 193, 195, 201
- Tensile dot4能力（gfx900相当）
	- `Tensile/AsmCaps.py`: 128, 155, 158, 159

### 12.5 判定ルール（チェックボックス）

- [ ] 「フォールバック成立」: 先行候補が `Not applicable` になり、同ケース内で後続候補が `Success` / 実行された
- [ ] 「MLIR->非MLIRフォールバック」: `ConvMlirIgemm*` 不適用後に ASM/DLOPS が実行された
- [ ] 「DP4A代替の疑い」: INT8実行は成功し、対象HSACOで `v_dot4_i32_i8|v_dot4c_i32_i8|sdot4` が見えない

### 12.6 ケース完了時の成果物

- [ ] 元ログ: `<CASE_ID>.log`
- [ ] 抽出ログ: `<CASE_ID>.trace_extract.log`
- [ ] 対応表: `<CASE_ID>.trace_map.md`（上記テンプレートを転記して記入）
- [ ] 判定: `fallback_confirmed / fallback_not_confirmed / need_more_cases`

## 13. 抜け漏れ再監査（コードベース全体・第2版）

本節は「主要推論経路の取りこぼしがないか」を再走査した結果。

### 13.1 再走査の範囲

- 対象ディレクトリ
	- `rocm-libraries/projects/miopen`
	- `rocm-libraries/projects/rocblas`
	- `rocm-libraries/projects/hipblaslt`
	- `rocm-libraries/projects/composablekernel`
	- `rocm-libraries/shared/tensile`
- 重点キーワード
	- `gfx900`, `IsApplicable`, `implicit_gemm`, `xdlops`, `dlops`, `fallback`, `sdot4`, `v_dot4`

### 13.2 追加で確認できた主要経路（前版からの増分）

#### A) MIOpen: Winograd/旧ASM系にも gfx900 条件が残存

- Winograd優先分岐
	- `miopen/src/solver/conv/conv_winoRxS.cpp:210`
	- gfx900/gfx906 で v21 優先ロジック。
- MP Bidirectional Winograd
	- `miopen/src/solver/conv/conv_MP_bidirectional_winograd.cpp:202,210`
	- gfx900/gfx906/gfx908 限定・workspace条件。
- Multipass Winograd WrW
	- `miopen/src/solver/conv/conv_multipass_wino3x3WrW.cpp:490,501`
	- gfx8/gfx900/gfx906/gfx908/gfx90a 分岐。
- Binary Winograd
	- `miopen/src/solver/conv/conv_bin_winoRxS.cpp:265,270`
	- `miopen/src/solver/conv/conv_bin_wino3x3U.cpp:61`
- 旧ASM direct系
	- `miopen/src/solver/conv/conv_asm_5x10u2v2f1.cpp:68`
	- `miopen/src/solver/conv/conv_asm_5x10u2v2b1.cpp:68`
	- `miopen/src/solver/conv/conv_asm_7x7c3h224w224k64u2v2p3q3f1.cpp:76`

解釈:
- 「implicit GEMMだけ」ではなく、Winograd/旧ASMにも gfx900 生存経路がある。

#### B) MIOpen: XDLops系ソルバは gfx900 で系統的に落ちる

- XDLops適用ガード（代表）
	- `miopen/src/solver/conv/conv_mlir_igemm_fwd_xdlops.cpp:66`
	- `miopen/src/solver/conv/conv_mlir_igemm_bwd_xdlops.cpp:52`
	- `miopen/src/solver/conv/conv_mlir_igemm_wrw_xdlops.cpp:53`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_xdlops.cpp:292`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_bwd_data_xdlops.cpp:294`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_bwd_v1r1_xdlops.cpp:788`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_v4r4_xdlops.cpp:1000`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_v4r4_xdlops_padded_gemm.cpp:1061`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_fwd_v4r5_xdlops.cpp:1030`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_wrw_v4r4_xdlops.cpp:1068`
	- `miopen/src/solver/conv/conv_hip_implicit_gemm_wrw_v4r4_xdlops_padded_gemm.cpp:1128`

- 根本判定
	- `miopen/src/include/miopen/solver/implicitgemm_util.hpp:101-105`
	- 既定 `IsXdlopsSupport` は gfx908/gfx90a/gfx942/gfx950。
	- gfx900 は通常 false。
	- `miopen/src/include/miopen/solver/implicitgemm_util.hpp:95` の環境変数でエミュレート強制可能。

解釈:
- gfx900では XDLops群が共通ガードで落ち、非XDLops群へフォールバックする構図がより明確。

#### C) rocBLAS: 実行時フォールバックが明示実装されている

- hipBLASLt利用判定
	- `rocblas/library/src/tensile_host.cpp:1169,1213`
- hipBLASLt失敗時の明示フォールバック
	- `rocblas/library/src/tensile_host.cpp:1232`
	- ログ: "hipBlasLT failed, falling back to tensile."
- 例外時フォールバック
	- `rocblas/library/src/tensile_host.cpp:1239` 近傍（catch節）
- Tensile解探索失敗時の再フォールバック（XF32->FP32）
	- `rocblas/library/src/tensile_host.cpp:1154`
	- `rocblas/library/src/tensile_host.cpp:1161`
	- `rocblas/library/src/tensile_host.cpp:1280`

解釈:
- rocBLASは「hipBLASLt -> Tensile」「XF32 -> FP32」の二段フォールバックを実装済み。

#### D) hipBLASLt内部（rocBLASLt/TensileLite）にも gfx900 マップが残存

- `hipblaslt/library/src/amd_detail/rocblaslt/src/tensile_host.cpp:1932`
- `hipblaslt/library/src/amd_detail/rocblaslt/src/tensile_host.cpp:1944,1946`
- `hipblaslt/library/src/amd_detail/rocblaslt/src/tensile_host.cpp:2239`

解釈:
- hipBLASLt系でも gfx900 への LazyLoading 経路が維持されている。

#### E) MIOpen GEMM（Conv以外）でのバックエンド分岐補足

- backend強制変数
	- `miopen/src/gemm_v2.cpp:245,640`
- backendスイッチ
	- `miopen/src/gemm_v2.cpp:684`（ほか複数）
- hipBLASLtでint8非対応（例外）
	- `miopen/src/gemm_v2.cpp:518`
- rocBLAS経路
	- `miopen/src/gemm_v2.cpp:687`（ほか複数）

解釈:
- MIOpen GEMMは「backend選択」で分岐し、hipBLASLtで int8 は即エラー。自動フォールバックはこの関数内では見えないため、呼び出し側ポリシー依存。

### 13.3 「主要経路の抜け漏れ」判定

現時点の監査結論:
- 主要推論計算経路（Conv/GEMM）としては、以下を押さえれば実機検証上の取りこぼしは小さい。
	1) MIOpen: MLIR(非XDLops)除外、ASM implicit GEMM v4r1 dynamic、DLOPS、Winograd/旧ASM
	2) MIOpen: XDLops群の共通不適用（gfx900では通常false）
	3) rocBLAS: hipBLASLt失敗時 Tensile フォールバック、XF32->FP32フォールバック
	4) CK/Tensile: dot4不在時の代替積和系

未確認/低優先:
- AMDMIGraphX本体ソースはこのワークツリーでは確認できず（`ROCm/tools/rocm-build/build_amdmigraphx.sh` は存在）。
	- 本調査は `rocm-libraries/projects` 主体の経路監査として完了扱い。

### 13.4 次回実機実験で必ず取るログ（最小追加）

- MIOpenログ
	- `Not applicable` 行 + 最終採用solver名
- rocBLAS verbose
	- "hipBlasLT failed, falling back to tensile."
	- "No Tensile solution found for XF32, fall back to FP32"
- 逆アセンブル
	- `v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4` の有無

## 14. 半自動トレース収集スクリプト

作成済みスクリプト:
- `lab_notebook/notes/vega_investigations/run_vega_path_case.sh`

このスクリプトは以下を1回で実行する。
- 対象コマンドの実行と生ログ保存
- フォールバック痕跡の抽出ログ生成
- solver抽出ログ生成
- `trace_map.md` 雛形の自動生成
- （任意）HSACO逆アセンブルとdot4命令抽出

### 14.1 基本使い方

```bash
cd /home/limonene/ROCm-project/tank

lab_notebook/notes/vega_investigations/run_vega_path_case.sh fp32_nchw_3x3_fwd_n32 -- \
	miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1
```

出力先（既定）:
- `~/vega_path_check_logs/<CASE_ID>.log`
- `~/vega_path_check_logs/<CASE_ID>.trace_extract.log`
- `~/vega_path_check_logs/<CASE_ID>.solver_extract.log`
- `~/vega_path_check_logs/<CASE_ID>.trace_map.md`
- `~/vega_path_check_logs/<CASE_ID>.meta.txt`

### 14.2 HSACOのdot4確認も同時に行う場合

```bash
TARGET_HSACO=/path/to/kernel.hsaco \
LLVM_OBJDUMP=llvm-objdump \
lab_notebook/notes/vega_investigations/run_vega_path_case.sh int8_case -- \
	miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1
```

### 14.3 運用ルール

- 1ケース1 `CASE_ID` を厳守する（ログ混線を防ぐため）。
- `trace_map.md` の表は、抽出ログを見ながら人手で最終確定する。
- `fallback_confirmed / fallback_not_confirmed / need_more_cases` の判定を必ず残す。

## 15. hint（参考資料）反映時のコード優先ルール

このノートは、旧 `rocm7_2-vega-path_hint.md` の内容を参考にしつつも、
最終判定は必ず `docs-ref/AMD_reference/AMD_Official/ROCm_AMD_Repo` の生コードを真実源として行う。

### 15.1 判定ルール（固定）

- `code_verified`: 対応する分岐/ログ文言/適用条件をコードで直接確認できたもの。
- `hint_only`: 参考資料にはあるが、このワークツリーのコードでは未確認のもの。
- `out_of_scope`: 本ノートの主題（gfx900推論経路トレース）から外れるもの。

### 15.2 hint由来主張の仕分け（推論経路のみ）

| 項目 | 判定 | 根拠コード | 備考 |
|---|---|---|---|
| gfx900でMLIR iGEMMが落ちる | `code_verified` | `miopen/src/solver/conv/conv_mlir_igemm_{fwd,bwd,wrw}.cpp` | `StartsWith(device_name, "gfx900")` で false |
| gfx900でASM implicit GEMM v4r1 dynamicが候補に残る | `code_verified` | `miopen/src/solver/conv/conv_asm_implicit_gemm_*_v4r1_dynamic.cpp` | `gfx900/gfx906` 条件あり |
| MIOpen候補は `IsApplicable` で順次スキップされる | `code_verified` | `miopen/src/include/miopen/find_solution.hpp`, `miopen/src/problem.cpp` | `Not applicable` ログと一致 |
| gfx900でXDLops系が共通ガードで落ちる | `code_verified` | `miopen/src/include/miopen/solver/implicitgemm_util.hpp` と各 xdlops solver | 既定 `IsXdlopsSupport` は gfx900 を含まない |
| rocBLASの `hipBLASLt -> Tensile` フォールバック | `code_verified` | `rocblas/library/src/tensile_host.cpp:1232` | `hipBlasLT failed, falling back to tensile.` |
| rocBLASの `XF32 -> FP32` フォールバック | `code_verified` | `rocblas/library/src/tensile_host.cpp:1161` | `No Tensile solution found for XF32, fall back to FP32` |
| rocBLASのgfx900 lazy loadingマップ | `code_verified` | `rocblas/library/src/tensile_host.cpp:232,238,240` | `getLazyLoadingArch` で `gfx900` を返す |
| dot4不在時の代替積和（DP4A相当） | `code_verified` | `composablekernel/include/ck/utility/inner_product.hpp` | `static_for<0,4,1>` の逐次積和分岐 |
| Tensile能力表でgfx900相当dot4無効 | `code_verified` | `rocm-libraries/shared/tensile/Tensile/AsmCaps.py` | `(9,0,0)` で `v_dot4*` が false |
| MIGraphX EP詳細設定（fp8/tune等） | `hint_only` | この調査ワークツリーでは未確認 | MIGraphX本体ソース監査が別途必要 |
| RDNA4固有不具合（特定issue） | `hint_only` | issueベースでコード未照合 | 本ノート主題外（gfx900優先） |
| 化学計算（LAMMPS/GROMACS）経路 | `out_of_scope` | - | 本ノートは推論経路に限定 |

### 15.3 参考資料を使うときの禁止事項

- 参考資料の文章だけで「経路が存在する」と断定しない。
- issue/ブログ/外部記事のログ文言を、そのままコード根拠として扱わない。
- `code_verified` 以外の項目を、結論サマリや成功判定に混ぜない。

### 15.4 次回更新時の追記テンプレート（差分管理）

新しい主張を追加する場合は、以下4点を必須で付与する。

1) 主張（1行）
2) 判定（`code_verified` / `hint_only` / `out_of_scope`）
3) 根拠ファイルと行番号
4) 実機ログでの確認コマンド（あれば）

### 15.5 文書整理ステータス（2026-03-12）

- 旧リサーチ文書 `rocm7_2-vega-path_hint.md` のうち、
	推論経路以外の背景情報は `README.md` に吸収した。
- 推論経路に関する最終判定は本ファイルを正本として維持する。

## 16. Vega推論経路の「維持・管理・補充」メカニズム（コード再監査）

この章は「経路が残っている」だけでなく、現代的な実装の中で
どう維持・管理・補充されているかをコードで再確認した結果。

### 16.1 維持（build-time）

#### A) rocBLASのGPU target定義に gfx900 が継続して含まれる

- `rocblas/CMakeLists.txt:80-85`
	- `TARGET_LIST_ROCM_5.6` から `TARGET_LIST_ROCM_7.1` まで `gfx900` を含む定義が継続。

解釈:
- 少なくともビルド構成レベルでは、gfx900 を完全に切り捨てる設計にはなっていない。

#### B) Tensile backend自体を標準で有効

- `rocblas/next-cmake/CMakeLists.txt:46`
	- `ROCBLAS_ENABLE_TENSILE` が既定ON。
- 同ファイル:57,110,266,276,339
	- Tensile有効時のビルド/導入フローが分岐実装されている。

解釈:
- GEMM実装基盤（Tensile）を維持したまま世代拡張する設計で、旧世代経路も同じ枠組みで管理される。

### 16.2 管理（runtime selection / policy）

#### A) MIOpen finder制御（機能ゲート）

- `miopen/src/conv/solver_finders.cpp:40-44`
	- `MIOPEN_DEBUG_CONV_WINOGRAD`, `MIOPEN_DEBUG_CONV_IMPLICIT_GEMM`, `MIOPEN_DEBUG_COMPILE_ONLY`。
- 同:98,109,110
	- ImplicitGEMM候補列挙 (`FindAllImplicitGemmSolutions` / `FindImplicitGemmWrWAllSolutions`)。
- 同:222,244,360
	- `EvaluateInvokers` で実測評価し、`RegisterInvoker` で採用結果を登録。

解釈:
- 環境変数 + 実測評価 + invoker登録で、旧経路を含む候補群を運用時に管理している。

#### B) MIOpen AIヒューリスティクスの適用判定

- `miopen/src/conv/heuristics/ai_heuristics.cpp:235-248`
- `miopen/src/conv/heuristics/ai_heuristics.cpp:335-348`
- `miopen/src/conv/heuristics/ai_heuristics.cpp:428-441`
	- `applicable_solvers` を数え、0なら `TunaNet Inapplicable`。
- 同:540,666
	- 予測結果を `StorePredictionCache`。

解釈:
- モデル予測を盲信せず、適用可能solverが無い場合は明示的に無効化して安全側に戻す管理設計。

### 16.3 補充（fallback / compatibility）

#### A) rocBLAS backendフォールバック

- `rocblas/library/src/tensile_host.cpp:1232`
	- `hipBlasLT failed, falling back to tensile.`
- 同:1161
	- `No Tensile solution found for XF32, fall back to FP32`。
- 同:232,238,240
	- `getLazyLoadingArch` で `gfx900 -> LazyLoadingInit::gfx900`。

解釈:
- 実行時失敗を吸収する多段フォールバックと、世代別lazy loadingの両方が補充機構として機能。

#### B) ROCm設計文書上のbackend制御ポリシー

- `rocblas/docs/reference/env-variables.rst:23-39`
- `rocblas/docs/conceptual/rocblas-design-notes.rst:34-39`
	- `ROCBLAS_USE_HIPBLASLT` / `ROCBLAS_USE_HIPBLASLT_BATCHED` で backend 方針を制御。

解釈:
- 実装コードだけでなく運用ポリシーも明文化され、障害回避手段が公式に管理されている。

#### C) Tensileのcatalog/fallback構造

- `shared/tensile/docs/src/conceptual/solution-selection-catalogs.rst:96`
	- `TensileLibrary_lazy_gfx900.yaml`
- 同:100
	- `...fallback_gfx900.hsaco`

解釈:
- ライブラリ構成上、gfx900向けlazy catalogとfallback code objectを持つ設計概念が明示。

#### D) dot4不在時の補充ロジック

- `shared/tensile/Tensile/AsmCaps.py:128,155,158`
	- gfx900相当 `(9,0,0)` で dot4 capability を立てない。
- `shared/tensile/Tensile/Code.py:628`
	- `int8 not implemented yet for gfx900` コメント。
- `shared/tensile/Tensile/Code.py:635`
	- 条件成立時の `v_dot4_i32_i8` 出力コード。

解釈:
- 世代能力テーブルで制約を表現し、利用可能条件でのみdot4を使う補充型設計になっている。

### 16.4 「推論経路の取りこぼし」再判定

今回追加監査後の結論:

- 主経路（MIOpen/rocBLAS/CK-Tensile）だけでなく、
	build構成・ヒューリスティクス・runtime policy・catalog構造まで根拠が揃った。
- 「残存している」だけでなく、
	`維持(build) + 管理(selection) + 補充(fallback)` の3層で説明可能になった。

### 16.5 まだ残るギャップ（明示）

- AMDMIGraphX本体の同等粒度監査は未実施（このワークツリーでは主要ソース未確認）。
- 実機ログでの最終確証（ケース別 `trace_map` 埋め）は継続タスク。

### 16.6 最終チェック（この調査の完了条件）

- [x] gfx900推論経路のコード証跡
- [x] フォールバック経路の行番号トレース
- [x] dot4代替経路の証跡
- [x] 維持・管理・補充メカニズムのコード証跡
- [ ] 実機ケースの `fallback_confirmed` を最低1件確定

