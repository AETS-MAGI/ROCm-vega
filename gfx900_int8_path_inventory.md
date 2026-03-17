# gfx900 INT8 経路 観測インベントリ

作成日: 2026-03-17
関連文書: `trace_map_static.md`, `trace_map_dynamic.md`, `solver_observation_log.md`, `provenance_map.md`

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

gfx900 (Vega64) における INT8 convolution 経路について、
**何が観測されたかを固定する**。

「触る価値」「難易度」「入口候補」のような作業計画寄りの評価は含めない。
必要になった場合は別紙 `gfx900_int8_workplan.md` に切り出す。

---

## 状態の定義

| 状態ラベル | 意味 |
|---|---|
| `自然選択` | 標準 MIOpenDriver 実行で自動的に選ばれた |
| `強制可能` | `-S <solver>` で強制指定した場合に成功した |
| `IsApplicable 除外` | `IsApplicable()` が `false` を返し、候補に入らない |
| `runtime failure` | 強制実行まで進んだが、実行時に失敗した |
| `artifact / tuning 不在` | コードパスは存在するが、対応する Perf DB / catalog が観測されていない |
| `未観測` | 本調査では対象条件での確認を実施していない |

---

## 観測テーブル

| 経路 | 種別 | 状態 | 落ちる位置 | 観測根拠 | 物理制約 / ソフト制約 | 修正可能主体 | 留保 / Open Question |
|---|---|---|---|---|---|---|---|
| `ConvDirectNaiveConvFwd` | Naive fallback | **自然選択**（INT8 の全観測ケースで選択） | — | 15+ ケース全件で Solution 85 として選択。`solver_observation_log.md` | なし（常時 applicable 設計） | — | 最適化なし。性能基準が低い |
| `ConvMlirIgemmFwd` | MLIR iGEMM | **IsApplicable 除外** + **runtime failure**（強制時） | `IsApplicable()` → `StartsWith("gfx900") return false` / 強制時は Perf DB 不在 → `boost::optional` crash | `conv_mlir_igemm_fwd.cpp:188`（code_verified）/ 強制実行ログ（runtime_verified） | **ソフト制約**（`llvm-project-private#389` 参照のコード判断。ただし根拠非公開） | AMD(M) 強い。private #389 解消が前提 | private issue の技術的根拠は外部から確認不可 |
| `ConvCkIgemmFwdV6r1DlopsNchw` | CK iGEMM (DLOPS) | **IsApplicable 除外** | `IsApplicable()` が `false` を返す（NCHW/NHWC, 1x1/3x3, n=1/16/32 等 15+ ケース全件 `rc=0x3`） | 強制実行グリッド全件（runtime_verified） | **capability / 実装制約寄り**（観測した CK iGEMM path は全件 `not applicable`。`dot4` 系 capability 依存が示唆されるが、CK 全体へは一般化しない） | AMD(M)。CK の該当 path 側修正が必要 | CK 全体の将来可能性はここから一般化しない |
| `ConvHipImplicitGemmFwdXdlops` | Xdlops iGEMM | **IsApplicable 除外** | `IsXdlopsSupport() → false`（gfx908 未満） | `implicitgemm_util.hpp:101-105`（code_verified）/ 強制実行で assertion abort（runtime_verified） | **物理制約**（MFMA 命令が gfx900 に存在しない） | — | 物理的に解決不可 |
| `ConvHipImplicitGemmForwardV4R5Xdlops` | Xdlops iGEMM | **IsApplicable 除外** + **runtime failure**（強制時） | `IsXdlopsSupport() → false` / 強制時は `intrin_mfma_*` / `gcnasm_mfma_*` compile 失敗 → `Code object build failed` | 強制実行ログ `rc=0x7`（runtime_verified） | **物理制約**（MFMA 命令依存） | — | 物理的に解決不可 |
| `ConvAsmImplicitGemmV4R1DynamicFwd*` | ASM legacy | **未観測** + **runtime failure**（強制 1x1） | 自然選択側では `Not applicable` を反復観測 / `-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1` では `CompileSolution` → `ConvolutionForwardImmediate` 後に GPU fault | `trace_map_dynamic.md`、`vega64_int8_force_asm_v4r1_1x1.trace_map.md`（runtime_verified） | **実装制約寄り**（自然選択境界と強制実行境界が一致しない） | AMD(M) | `Not applicable` の主因が dtype か shape かは未切り分け |
| Winograd 系（`ConvBinWinograd3x3U` 等） | Winograd | **未観測** | INT8 条件での自然選択・強制確認は本調査では未実施 | FP32 での自然選択観測は別文書にあり。INT8 は未確認 | 不明 | AMD(M) | FP32 では gfx900 の主戦場だが、INT8 の適用可否はこの文書では確定しない |
| rocBLAS / Tensile INT8 経路 | GEMM backend | **未観測** | `gemm_v2.cpp` の GEMM backend 切替経路は存在するが、INT8 での gfx900 catalog の有無を本調査では直接確認していない | `tensile_host.cpp` の `getLazyLoadingArch` に gfx900 が存在すること（code_verified）。INT8 catalog の実在は未確認 | 不明（catalog 有無・dtype サポート状況に依存） | AMD(M) + ExtC | INT8 の Tensile catalog が gfx900 向けに存在するか要確認 |
| MIOpen INT8 Perf DB（gfx900） | チューニングデータ | **未観測** | gfx900 向け Perf DB 自体は出荷済みだが、INT8 エントリの抽出・同定は本調査で未実施 | Perf DB 実測（shipped_artifact_verified）。gfx900 全体では 169K 行確認。INT8 エントリ有無は個別確認が必要 | 不明 | AMD(M) | 「INT8 tuning 不在」まではまだ言えない |

---

## 横断的観測（Fact）

- **gfx900 の INT8 convolution で自然選択される solver は `ConvDirectNaiveConvFwd`（Naive solver）のみ**（runtime_verified、15+ ケース）
- `-S ConvAsmImplicitGemmV4R1DynamicFwd_1x1` の強制実行では `solution_id = 63` で `CompileSolution` / `ConvolutionForwardImmediate` まで進むが、実行完了前に `Memory access fault by GPU node-1` で停止する
- 物理制約（MFMA / xdlops / dot4 の不在）で除外される経路と、ソフト制約（実装判断・private issue）で除外される経路が混在している
- Tensile `AsmCaps.py` の `(9, 0, 0)` では `v_dot4_i32_i8 = False` を確認できる
- FP32 では有効な ASM v4r1 dynamic / Winograd が存在する一方、INT8 では同等の自然選択経路は未観測である

## 横断的解釈（Interpretation）

- INT8 の「落ちる位置」は経路によって異なる。MLIR は `IsApplicable()` の arch gate、CK は `IsApplicable()` ベースの capability 境界、ASM v4r1 は自然選択境界と強制実行境界がずれ、Xdlops 系は命令セット不在で落ちる。これらは独立した原因であり、一括で解決する手段は存在しない。
- 物理制約で除外される経路（Xdlops 系）は原理的に gfx900 で成立しにくい。ソフト / 実装制約で止まっている経路（MLIR iGEMM、ASM v4r1 の INT8 条件）は、実装変更で境界が変わる余地があるが、修正可能主体と公開根拠の範囲に制約がある。

## Open Question / Limitation

1. **rocBLAS / Tensile の INT8 経路**: gfx900 向け INT8 catalog の実在は本調査では未確認。要追加調査
2. **MIOpen Perf DB の INT8 エントリ**: gfx900 向け Perf DB 自体は確認済みだが、INT8 の有無は未精査
3. **ASM v4r1 の自然選択不成立条件**: `Not applicable` の主因が dtype か shape か、あるいは別条件かは未切り分け
4. **Winograd の INT8 条件**: この文書では INT8 での適用可否を直接確認していない

---

## 本文書が主張しないこと

- gfx900 における INT8 最適化の実現可能性を断定するものではない
- 各経路の「触る価値」「優先度」「実装難易度」を評価するものではない
- 社内意思決定や private issue の内容を推定するものではない
- 特定組織や個人への批判を目的とするものではない
