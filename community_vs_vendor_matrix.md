# Community vs Vendor Matrix for gfx900

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 目的

`gfx900` の残存経路を「AMD が維持している / コミュニティが支えている」の二択に単純化せず、
経路ごとに **誰の投入が観測され、誰の補修が観測され、何が出荷され、実務上どの程度効いているか** を表形式で固定する。

本メモの行番号は `provenance_map.md` と相互参照しやすいよう `P1-P8` を採用する。
ただし matrix 側では、`provenance_map.md` の `P4` と `P5` を実務上近いものとしてまとめて `P4` とし、
その代わりに現行の「使えない modern path」である `CK / XDLops` を `P5` として追加している。

---

## 列の意味

| 列 | 意味 |
| --- | --- |
| `AMD maintained` | AMD org member / `@amd.com` メール等、AMD 側の投入・補修が公開上確認できるもの |
| `AMD related / unknown` | AMD 関連の可能性はあるが、公開情報だけでは所属や立場を断定しにくいもの |
| `external contributor` | 非 `@amd.com` ドメインで、AMD 所属を公開根拠から断定できない contributor |
| `shipped evidence` | `/opt/rocm` や配布物から観測できる出荷上の痕跡 |
| `current status` | 2026-03-17 時点の公開コード・実機観測ベースの状態 |
| `practical effect for gfx900` | Vega ユーザにとって実務上どの程度意味があるか |

---

## Matrix

| Row | Path | AMD maintained | AMD related / unknown | external contributor | shipped evidence | current status | practical effect for gfx900 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `P1` | MLIR iGEMM 除外 | `2407d2f` / PR `#1328` による明示 disable、ctest 分離まで AMD 側で確認可能 | — | 2023 の URL 修正はあるが、除外方針の主体ではない | source 上の gating 痕跡は残るが、実用的な shipped path は未確認 | `ConvMlirIgemm*` は `gfx900` を `IsApplicable()` で reject | MLIR iGEMM は実務上使えない |
| `P2` | ASM v4r1 dynamic（legacy solver） | `carlushuang` / `chao.liu2@amd.com` / `shaojie.wang@amd.com` による投入・補修が確認できる | 初期の `Shaojie WANG` は個人メール時期があり、初期所属の読みは限定つき（ただし後のコミットで `shaojie.wang@amd.com` への切り替えを確認済み。AMD maintained 寄りに読んでよい根拠あり） | `Artem Tamazov` による制御系補修あり | 現行 MIOpen 実体で自然選択と強制選択を確認済み | `gfx900/gfx906` 専用 legacy solver として残存 | FP32 の主要な実用経路 |
| `P3` | Winograd | Vega20 向け workaround や env 整備など、後年の AMD 側補修が観測される | 初期投入者の一部は公開情報だけでは AMD 所属を断定しにくい | `Artem Tamazov`, `Kamil` などの投入が確認できる | 現行 MIOpen で FP32 path の残存を確認済み | FP32 側で広く残存、FP16 は `gfx906+` 側に寄る | gfx900 で「まだ速い」側の主戦場 |
| `P4` | WORKAROUND sramecc / MP_bidir | `MP_bidirectional_winograd` には AMD 側の近年補修が入る | — | `WORKAROUND_ISSUE_1204` と `MP_bidirectional_winograd` の初期投入は外部 contributor 起点 | shipped source / runtime path として残存 | workaround は透過的に有効、MP_bidir は制約付きで残存 | 誤判定吸収と一部 Winograd path 維持に効く |
| `P5` | CK / XDLops 系 | modern solver 群そのものは AMD 側開発の層に属する | — | — | code は存在するが `gfx900` 向け実用 path の出荷優位は未確認 | 観測した CK iGEMM 系 path は `not applicable`、XDLops 系は capability 不成立 | gfx900 では modern fast path としては効かない |
| `P6` | Tensile fallback | rocBLAS / Tensile の基盤統合は AMD 側 | 初期統合の一部 contributor の立場は公開情報だけでは混在 | `cgmb` の `gfx900:xnack-`、`GZGavinZhao` の fallback library 補修が確認できる | rocBLAS 配布物と Tensile catalog が出荷される | source-build / fallback 側の残存性が外部補修で強化 | GEMM 側の hard drop を和らげる |
| `P7` | rocMLIR gating | `miirCreateHandle` 周辺、`ConvMlirIgemm*` gating、private issue 参照はいずれも AMD 側痕跡 | — | — | shipped 実体でも強制実行時に失敗経路を確認 | gating は AMD 側 control plane にあると読める | 公開側から reopen しにくい |
| `P8` | shipped artifacts / packaging | rocBLAS library、Perf DB、firmware は build / packaging 側の AMD 出荷物として観測 | — | distro 再配布はありうるが、origin の主体ではない | `rocBLAS` 128 kernels、Perf DB 169,182 行、vega10 firmware 16 files を確認 | 配布層では `gfx900` の痕跡がまだ厚い | 「公式非推奨でも動く」土台を支える |

---

## 読み取り

### Fact

- `P1`, `P7`, `P8` は、少なくとも公開上は AMD 側が強く握る層として観測される。
- `P2`, `P3`, `P4` は、初期投入・後年補修・実運用が単一主体ではない。
- `P6` は、AMD 側の基盤の上に外部 contributor の補修が重なった経路として読める。
- `P5` は「存在する modern path」だが、観測した範囲では `gfx900` の実用経路にはなっていない。

### Interpretation

- `gfx900` の残存は、「AMD 維持」か「コミュニティ維持」かの単純な二分では説明しにくい。
- 実務上は、
  `P2-P4` が legacy solver 側の実行可能性を支え、
  `P6` が BLAS / Tensile 側の fallback 残存を支え、
  `P8` が配布層の摩擦を下げている、
  という分業として読むのが自然である。
- 一方で `P1` と `P7` は、公開側から変更しにくい control plane として残っている。

### Open Question / Limitation

- 初期 contributor の一部について、公開情報だけで AMD 所属・契約関係を確定できない。
- `P8` の出荷継続が将来リリースでも続くかは、現時点では断定できない。
- `P5` の CK path については、「観測した範囲で not applicable」までは言えるが、
  CK 全体の将来可能性をここから一般化することはしない。

---

## 主要参照

- `provenance_map.md`
- `support_boundary.md`
- `rocm-github-investigate.md`
- `final_hypothesis.md`
- `facts.md`

---

## 本文書が主張しないこと

- AMD の内部方針や private issue の本文を断定するものではない
- contributor の所属や契約形態を公開情報以上に推定するものではない
- 単一の経路から ROCm 全体の support policy を完全に代表させるものではない
- 特定組織や個人への批判を目的とするものではない
