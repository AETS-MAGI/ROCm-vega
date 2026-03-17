# MIOpen クラス責務マップ

作成日: 2026-03-17
関連: `final_hypothesis.md`（逆参照先）、`trace_map_static.md`、`device_capability_flow.md`

---

## このドキュメントの役割

**目的は仮説Bの再証明ではない。**

このドキュメントは、`final_hypothesis.md` が「MIOpen はこういう責務境界を持っており、
gfx900 の生存はその構造の自然な帰結である」と主張するときに、
その「構造」を指示するための**錨文書**として機能する。

具体的には以下の3点を固定する：

1. `frontend → TargetProperties → ConvolutionContext → solver registry → solution → immediate`
   の主要クラスとその責務（一クラス一行）
2. 各クラスが「capability 判定 / solver 選択 / kernel 発行」のどの層を担うか
3. MIOpen と他層（rocMLIR / Tensile / CK）との接続点

**このドキュメントを書いたあとで `final_hypothesis.md` が「§ クラス責務マップ参照」と
書いて済む状態を作ることがゴール。**

---

## 主要フロー概観

```
[User API]
  miopenConvolutionForwardImmediate()
  miopenFindConvolutionForwardAlgorithm()
        |
        v
[Handle / Descriptor 層]
  miopenHandle_t  ............  GPU context（stream / device）を保持
  ConvolutionDescriptor  .....  conv パラメータ（stride / pad / dilation 等）を保持
        |
        v
[Device 識別層]
  TargetProperties  ..........  device name → arch name の正規化
                                (例: "Vega10" → "gfx900", sramecc workaround)
        |
        v
[Problem 記述層]
  ExecutionContext  ...........  stream / device を束ねる実行文脈
  ConvolutionContext  .........  ExecutionContext + problem descriptor の合成体
  ProblemDescription  .........  入力 shape / dtype / layout の記述
        |
        v
[Solver 選択層]
  SolverContainer / FindCore  .  solver 全件列挙 → IsApplicable フィルタ
  SolverBase::IsApplicable()  .  各 solver の適用条件判定（arch / dtype / shape）
  SolverBase::GetSolution()  ..  適用可能 solver から Solution を生成
        |
        v
[Solution / Invoker 層]
  ConvSolution  ...............  kernel launch params / workspace size 等を保持
  Invoker  ....................  実際の kernel 発行オブジェクト
        |
        v
[Kernel / 外部バックエンド 層]
  HIPOCProgram  ...............  HIP kernel のコンパイル・ロード
  mlir_build.cpp  .............  rocMLIR 接続点（MiirIsConfigApplicable / miirCreateHandle）
  gemm_v2.cpp  ................  GEMM バックエンド切替（hipBLASLt / rocBLAS / Tensile）
```

---

## クラス別責務表

| クラス / モジュール | 主責務 | 層 | 主要ファイル |
|---|---|---|---|
| `miopenHandle_t` | GPU stream / device context の保持 | frontend | `handle.hpp` |
| `ConvolutionDescriptor` | conv パラメータ記述 | frontend | `convolution.hpp` |
| `TargetProperties` | device name 正規化・arch 識別 | capability 判定 | `target_properties.cpp` |
| `ExecutionContext` | stream / device 実行文脈 | capability 判定 | `execution_context.hpp` |
| `ConvolutionContext` | 実行文脈 + 問題記述の合成 | capability 判定 | `conv/context.hpp` |
| `ProblemDescription` | shape / dtype / layout 記述（conv 専用） | capability 判定 | `miopen/conv/problem_description.hpp:145` |
| `SolverBase` | solver 共通インタフェース（IsApplicable / GetSolution） | solver 選択 | `solver.hpp` |
| `SolverContainer` | solver 全件列挙・フィルタ（`struct`） | solver 選択 | `find_solution.hpp:137` |
| `ConvSolution` | kernel launch params / workspace 保持 | solution | `conv_solution.hpp` |
| `Invoker` | kernel 発行関数オブジェクト（`using Invoker = std::function<void(...)>`） | solution | `invoker.hpp:39` |
| `HIPOCProgram` | HIP kernel コンパイル・ロード | kernel | `hipoc_program.hpp` |
| `mlir_build.cpp` | rocMLIR 接続（`miirCreateHandle` / `MiirIsConfigApplicable`） | 外部バックエンド | `mlir_build.cpp` |
| `gemm_v2.cpp` | GEMM バックエンド切替（hipBLASLt → rocBLAS → Tensile） | 外部バックエンド | `gemm_v2.cpp` |

---

## 他層との接続点

| 接続先 | 接続クラス / 関数 | 何を渡すか | 何を返すか |
|---|---|---|---|
| **rocMLIR** | `mlir_build.cpp` → `miirCreateHandle` | conv config (arch / dtype / shape) | MIIR handle / `nullptr`（失敗時） |
| **rocMLIR** | `mlir_build.cpp` → `miirLowerTuningParams` | handle + tuning params | `MIIR_SUCCESS` / `MIIR_INVALID_PARAM` |
| **rocBLAS / Tensile** | `gemm_v2.cpp` → `CallHipBlas` | GEMM descriptor | status（失敗時 Tensile fallback へ） |
| **CK** | `conv_ck_igemm_*.cpp` → CK kernel | conv config | compiled kernel object |
| **HIP runtime** | `HIPOCProgram::BuildCodeObjectInMemory` | kernel source / binary | code object（失敗時 throw） |

---

## gfx900 に対するフィルタ位置

```
TargetProperties
  └─ device_name = "gfx900"  ← sramecc workaround (ISSUE_1204) が適用される点

ConvolutionContext
  └─ IsXdlopsSupport() → false  ← XDLops 系 solver を全件除外する共通ガード

SolverBase::IsApplicable() の solver 別ゲート:
  ConvMlirIgemmFwd/Bwd/Wrw  → StartsWith("gfx900") → return false  [MLIR除外]
  ConvAsmImplicitGemmV4R1*  → StartsWith("gfx900") || StartsWith("gfx906") → pass
  ConvBinWinograd3x3U       → gfx803/gfx900/gfx906/gfx908 → pass (FP32)
  ConvHipImplicitGemmXdlops → IsXdlopsSupport() → false → 全除外
  ConvCkIgemmFwdV6r1Dlops   → IsApplicable() → false (gfx900 は CK 対象外)

mlir_build.cpp
  └─ miirCreateHandle → parseConvConfig / RockEnabled 失敗 → nullptr
  └─ Perf DB に gfx900 用 tuning 行なし → boost::optional crash  [runtime_verified]
```

---

## final_hypothesis への接続メモ

- **仮説A（表と設計の乖離）**: `SolverContainer` が全件列挙して `IsApplicable` でフィルタする設計上、gfx900 向け solver が「登録されている」こと自体は事実。表のサポート終了と設計上の生存は独立。
- **仮説B（設計の副産物）**: `IsXdlopsSupport()` / `IsApplicable()` は arch property を capability として扱う汎用フィルタ。gfx900 専用コードではなく、capability-based 設計の自然な帰結。
- **仮説C（保守主体の層別）**: 接続点（mlir_build.cpp / gemm_v2.cpp）はそれぞれ別チームが管理。MIOpen 単体を保守しても、rocMLIR 側の制約（private #389）には届かない。
- **仮説E（Layered Retreat）**: フィルタが solver 単位・dtype 単位・arch 単位で独立しているため、「一括削除ではなくパーツごとの後退」が構造的に自然に起きる。
