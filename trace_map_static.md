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
- `rocMLIR` 本体は未展開（`.git` のみ確認）なので、rocMLIR 側の関数境界は次フェーズで追記する。
- `MIIR_INVALID_PARAM` の最小再現ケースは `vega64_int8_force_mlir_fwd` に固定済み
  （ログ: `vega_path_check_logs/vega64_int8_force_mlir_fwd.log`）。
