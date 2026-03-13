# trace_map_static

作成日: 2026-03-13
目的: MIOpen 内の solver 登録・ID解決・MLIRビルド境界を静的に固定し、動的ログ読解の基準点にする。

---

## 1. Solver登録とID解決の基準点

### 1.1 登録テーブル（registry 側）

- 対象: `rocm-libraries/projects/miopen/src/solver.cpp`
- 観測:
  - `ConvHipImplicitGemmForwardV4R5Xdlops` 登録あり
  - `ConvCkIgemmFwdV6r1DlopsNchw` 登録あり
  - `ConvHipImplicitGemmFwdXdlops` 登録あり
  - `ConvMlirIgemmFwd/Bwd/WrW` と `ConvMlirIgemm*Xdlops` 登録あり

### 1.2 強制指定ID解決（fin interface 側）

- 対象: `rocm-libraries/projects/miopen/src/fin/fin_interface.cpp`
- 観測:
  - `case 80`: `ConvHipImplicitGemmForwardV4R5Xdlops`
  - `case 114`: `ConvCkIgemmFwdV6r1DlopsNchw`
  - `case 128`: `ConvHipImplicitGemmFwdXdlops`
  - `case 98/99/100`: `ConvMlirIgemmFwd/Bwd/WrW`

含意:
- `-S` 強制実行時に `solver_extract.log` で見える solver 名と ID は、上記 switch に直接対応する。

### 1.3 `ConvMlirIgemmFwd` の適用条件（MIOpen前段 gate）

- 対象: `rocm-libraries/projects/miopen/src/solver/conv/conv_mlir_igemm_fwd.cpp`
- 観測:
  - `ConvMlirIgemmFwd::IsApplicable()` に `gfx900` の明示拒否がある
    - `if(StartsWith(device_name, "gfx900")) return false;`
  - コメントで `https://github.com/ROCm/llvm-project-private/issues/389` 参照あり
- 含意:
  - Vega64 (`gfx900`) では、通常の solver 列挙経路では `ConvMlirIgemmFwd` は候補に残らない。
  - `-S 98` のような強制経路でのみ実行に進むため、失敗は「未サポート経路の強制実行」として扱うのが妥当。

---

## 2. MLIRビルド境界（MIIR）

### 2.1 MIIRエラー変換点

- 対象: `rocm-libraries/projects/miopen/src/mlir_build.cpp`
- 観測:
  - `check_miir_error` で `MIIR_INVALID_PARAM` を例外化
  - `MiirGenBin` で `miirLowerBin` -> `miirBufferGet`

含意:
- 動的ログで `MIIR_INVALID_PARAM` が出た場合、MIOpen 側ではこの変換点経由で失敗している。

### 2.2 code object 生成の分岐点

- 対象: `rocm-libraries/projects/miopen/src/hipoc/hipoc_program.cpp`
- 観測:
  - `BuildCodeObjectInMemory` で拡張子ごとに分岐
  - `.mlir` の場合は `MiirGenBin(params, binary)` を呼ぶ
  - `binary.empty()` なら `Code object build failed` を throw

含意:
- `Code object build failed` は `.mlir` 経路でも発生し得るが、
  "MLIR lowering失敗" と "HIP/OCLコンパイル失敗" をログと拡張子で分離して読む必要がある。

### 2.3 rocMLIR 側 MIIR API 実装アンカー

- 対象:
  - `rocMLIR/mlir/tools/rocmlir-lib/Miir.h`
  - `rocMLIR/mlir/tools/rocmlir-lib/rocmlir-lib.cpp`
- 観測:
  - `Miir.h` で `MiirStatus`（`MIIR_SUCCESS`, `MIIR_INVALID_PARAM`, `MIIR_INVALID_MODULE`, `MIIR_BUILD_FAILURE`）を定義
  - `rocmlir-lib.cpp` で以下の C API を実装
    - `miirCreateHandle`
    - `miirLowerTuningParams`
    - `miirLowerBin`
    - `miirBufferGet`
    - `miirGetExecutionDims`
    - `miirDestroyHandle`
  - `miirCreateHandle` は `parseConvConfig` / `isApplicable` / `RockEnabled` 失敗時に `nullptr` を返す
  - `miirLowerTuningParams` / `miirLowerBin` は pass 実行結果を `MIIR_SUCCESS` または `MIIR_BUILD_FAILURE` で返す

含意:
- MIOpen の `mlir_build.cpp::check_miir_error` で見える `MIIR_INVALID_PARAM` は、
  rocMLIR 側 API が返すステータス値を直接反映している。
- `Code object build failed` のうち `.mlir` 経路は、`miirLowerBin` と `miirBufferGet` の結果が
  MIOpen 側 `binary.empty()` 判定に渡る連鎖として説明できる。

### 2.4 rocMLIR 側の事前 gate 条件（候補）

- 対象: `rocMLIR/mlir/tools/rocmlir-lib/rocmlir-lib.cpp`
- 観測:
  - `miirCreateHandle` 内で以下の順に失敗判定し、失敗時は `nullptr` を返す
    1. `convGenerator.parseConvConfig(...)`
    2. `convGenerator.isApplicable()`
    3. `RockEnabled(config)`
  - `RockEnabled(config)` は以下を要求
    - layout が許可集合に含まれること
      - `(ngchw, gkcyx, ngkhw)`
      - `(nhwgc, gkyxc, nhwgk)`
      - `(ngc01, gkc01, ngk01)`
      - `(n01gc, gk01c, n01gk)`
    - `conf.inputDataTypeStr != "bf16"`（bf16入力は拒否）

含意:
- MIOpen 側で `MIIR_INVALID_PARAM` が観測されるケースの一部は、
  rocMLIR の handle 作成段階（parse/applicability/layout/dtype gate）で既に弾かれている可能性がある。
- gfx900 特有の拒否条件は、`convGenerator.isApplicable()` 側の詳細（arch判定）を次段で追う必要がある。

### 2.5 `ConvGenerator::isApplicable()` 実装の確認

- 対象:
  - `rocMLIR/mlir/lib/Dialect/Rock/Generator/ConvGenerator.cpp`
- 観測:
  - `ConvGenerator::isApplicable()` は `hasValidDimension()` の結果を返すだけ
  - `hasValidDimension()` で見ているのは主に以下
    - dilation/stride/padding の正当性
    - tensor dimension の正値
    - layout と次元対応の整合
    - input/filter/output channel/group の整合
    - output shape の算出整合
  - `isApplicable()` 自体には `gfx900` など arch 固有の明示拒否条件は見当たらない

含意:
- `miirCreateHandle` 失敗のうち、`isApplicable()` 経由は「次元整合性NG」が中心であり、
  arch 固有の拒否は別地点（`genConvModule` / pipeline）で起きる可能性が高い。

### 2.6 最小再現ケースとの 1:1 照合（`vega64_int8_force_mlir_fwd`）

- ケース条件（ログ観測）:
  - `NCHW`, `INT8`, `group=1`, `1x1`, `stride=1`, `pad=0`
- RockEnabled 条件との照合:
  - layout: `NCHW` 系は `ngchw/gkcyx/ngkhw` に対応し許可集合内
  - dtype: `INT8` であり `bf16` ではない
  - 結果: RockEnabled 単独では reject 根拠を確認できない

- MIOpen前段 gate との照合:
  - `ConvMlirIgemmFwd::IsApplicable()` は `gfx900` を明示的に reject
  - 最小再現ログでは本来候補外の solver (`id=98`) を強制実行

含意:
- 当該ケースはまず「MIOpenの適用条件で非対応な solver を強制実行している」ことが一次原因。
- `miirCreateHandle` の `nullptr` 分岐については、Fwd/INT8 のコード経路上
  `getKernelCount` と `getWorkspaceSize` は失敗しにくいため、実質的には
  `parseConvConfig` または `genConvModule` 側の失敗が優先候補。
- ただし、実行時にリンクされる `/opt/rocm` の実体が参照ソース（`ROCm_AMD_Repo`）と
  完全一致する保証はないため、最終確定にはランタイム実体での分岐ログ取得が必要。

補足（現時点の推定）:
- 参照ソース上の `ConvGenerator::genConvModule` は Fwd/INT8 の最小再現条件で
  failure しづらく、`nullptr` の主候補は `parseConvConfig` 側と見るのが自然。

---

## 3. 失敗シグネチャ別の静的アンカー

- `MIIR_INVALID_PARAM`
  - 起点: `mlir_build.cpp::check_miir_error`
  - 到達条件: MIIR API が `MIIR_INVALID_PARAM` を返す

- `Code object build failed`
  - 起点: `hipoc_program.cpp::BuildCodeObjectInMemory`
  - 到達条件: code object 生成後の `binary` が空

- `not applicable`
  - 起点: 各 solver の `IsApplicable`
  - 代表: `conv_ck_igemm_fwd_v6r1_dlops_nchw.cpp`

- assertion abort (`EXIT=134`)
  - 起点: MIOpen内部またはsolver実装内アサート
  - 代表観測: `ConvHipImplicitGemmFwdXdlops` 強制時

---

## 4. 本ファイルの使い方

1. 先に `solver_extract.log` で solver 名と ID を確定する。
2. 本ファイルの静的アンカーで、失敗位置を層（registry / applicability / build）に分ける。
3. `trace_map_dynamic.md` 側には「実行事実」のみを書き、因果解釈は本ファイルに寄せる。

---

## 5. 現状ステータス

- 2026-03-13 時点で、MIOpen 側の MLIR 接続点と solver id 80/114/128 は静的固定済み。
- rocMLIR 側の MIIR C API 実装アンカー（`Miir.h` / `rocmlir-lib.cpp`）を追記済み。
- `MIIR_INVALID_PARAM` の最小再現ケースは `vega64_int8_force_mlir_fwd` に固定済み
  （ログ: `vega_path_check_logs/vega64_int8_force_mlir_fwd.log`）。
