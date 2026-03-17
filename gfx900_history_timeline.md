# gfx900 History Timeline

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 目的

`gfx900` の扱いが、ROCm 内で一括に変化したのではなく、
**component ごとに別の速度で投入・補修・除外・残存した**ことを、日付つきで追える形に固定する。

この文書は `final_hypothesis.md` の `Layered Retreat` を、
`rocm-github-investigate.md` と `WD-Black/ROCm-repos` 配下の実リポジトリ確認で再整理した canonical timeline である。

---

## 対象ソース

- current clone:
  - `WD-Black/ROCm-repos/MIOpen`
  - `WD-Black/ROCm-repos/Tensile`
- legacy clone:
  - `WD-Black/ROCm-repos/00_legacy-repos/MIOpen`
  - `WD-Black/ROCm-repos/00_legacy-repos/Tensile`
- runtime / shipped artifact observation:
  - `/opt/rocm`
  - `/lib/firmware/amdgpu`

注記:
- 本タイムラインには、**このローカル環境で再確認できた項目だけ**を入れる。
- 以前に回収した release-note 断片のうち、`hipCUB` / `rocSOLVER` 側の記述は current mirror で再確認できていないため、ここでは補助扱いに留める。

---

## Canonical Timeline

| Date | P | Component | Observation | Evidence |
| --- | --- | --- | --- | --- |
| `2020-06-09` | `P2` | MIOpen | `947ae38e9` `#166` で `v4r1 dynamic` FWD が投入される | `00_legacy-repos/MIOpen` git log |
| `2020-07-28` | `P2` | MIOpen | `dce9c70d4` `#272` で `v4r1 dynamic` BWD が追加される | `00_legacy-repos/MIOpen` git log |
| `2020-08-06` | `P2` | MIOpen | `f094f46c3` `#317` で dynamic iGEMM WRW が追加される | `00_legacy-repos/MIOpen` git log |
| `2020-08-21` | `P4` | MIOpen | `412284ab4` `#358` で `MP_bidirect_winograd` が投入される | `00_legacy-repos/MIOpen` git show |
| `2021-06-23` | `P2` | MIOpen | `bed612951` `#1001` で Vega ASM igemm WRW kernel selection bug が修正される | `00_legacy-repos/MIOpen` git show |
| `2021-10-21` | `P4` | MIOpen | `d4c4cbfc9` `#1231` で `gfx900` 向け `sramecc` workaround が追加される | `00_legacy-repos/MIOpen` git show + current `target_properties.cpp` |
| `2021-12-22` | `P1` | MIOpen | `d1a42ea69` `#1328` で MLIR iGEMM non-xdlops から `gfx900` が明示除外される | `00_legacy-repos/MIOpen` git log |
| `2022-09-23` | `P6` | Tensile | `41236e39` `#1595` で `gfx900:xnack-` が追加される | `00_legacy-repos/Tensile` git show + current `Tensile/CHANGELOG.md` |
| `2022-10-05` | `P2/P3/P4` | MIOpen current tree | current clone では `e5c6ce1` により、v4r1 allow 条件、Winograd allow 条件、`sramecc` workaround などの line provenance が release-notes commit に集約されて見える | current `MIOpen` git log / blame |
| `2023-02-13` | `P3` | MIOpen | `b1d887eb4` `#1968` で Vega20 Winograd performance workaround が入る | `00_legacy-repos/MIOpen` git show |
| `2023-12-13` | `P1` | MIOpen | `2c1bdc775` `#2597` で private issue 参照は残したまま URL だけ更新される | `00_legacy-repos/MIOpen` git show |
| `2024-01-24` | `P6` | Tensile | `efbe0c0c` `#1862` で optimized logic 不在 arch 向け fallback library 生成が入る | `00_legacy-repos/Tensile` git show |
| `2024-02-06` | `P6` | Tensile | `6cc51b4b` `#1879` で `#1862` が revert される | `00_legacy-repos/Tensile` git show |
| `2024-03-06` | `P6` | Tensile | `5dce86e9` `#1897` で fallback libraries 方針が再投入される | `00_legacy-repos/Tensile` git show |
| `2025-03-11` | `P4` | MIOpen | `c3468b057` `#3552` で `ConvMPBidirectWinograd` の gfx9 制約に関わるテスト・注記が追加される | `00_legacy-repos/MIOpen` git show |
| `2026-03-17` | `P8` | shipped artifacts | `rocBLAS` kernels、MIOpen Perf DB、vega10 firmware が現行環境に出荷されていることを確認 | runtime / artifact observation |

---

## 読み取り

### Fact

- `2020-2021` は、`P2` と `P4` を中心に、`gfx900` 向け legacy solver と workaround が実装・補修されていた時期として観測される。
- `2021-12-22` の `P1` は、MLIR iGEMM だけが明示的に `gfx900` から外れた分岐点である。
- `2022-2024` は、MIOpen の modern path では除外が残る一方、Tensile fallback 側では `gfx900` 関連の補修が続く。
- `2025-03-11` の `P4` 更新は、少なくとも `gfx9` 系制約の明示化が後年も続いていたことを示す。
- `2026-03-17` 時点でも、配布層 (`P8`) では `gfx900` の痕跡が厚い。

### Interpretation

- `gfx900` の履歴は、「2021 年に終わった」でも「いまも広く維持されている」でもない。
- より正確には、
  `P1` では selective disable、
  `P2-P4` では legacy solver / workaround の残存、
  `P6` では fallback 側の補修、
  `P8` では packaging の残存、
  という **時間差のある layered retreat** として読むのが自然である。
- current `MIOpen` の `git blame` が `e5c6ce1` に寄りやすい点は、
  現行 tree だけでは pre-2022 の段階的変化が見えにくいことを意味する。
  そのため、歴史層の確認には `00_legacy-repos` が実務上ほぼ必須である。

### Open Question / Limitation

- `hipCUB` / `rocSOLVER` の release note 上の `gfx900` 追加・後退は、以前の調査メモには存在するが、この current mirror では再確認できていない。
- `2025-03-11` の `P4` 更新が「gfx900 維持」なのか「gfx9 系全体整理」の副産物なのかは、公開情報だけでは断定できない。
- `P8` の配布継続が今後の release でも続くかは未確定である。

---

## 補助メモ

### current tree の見え方に関する注意

current `MIOpen` では、`conv_mlir_igemm_fwd.cpp`、`target_properties.cpp`、
`conv_asm_implicit_gemm_v4r1_dynamic.cpp`、`conv_bin_wino3x3U.cpp` などの行 blame が
`e5c6ce1` (`2022-10-05`, `v2.18.0 release notes`) に集約されて見える箇所がある。

これは「2022-10-05 にすべてが導入された」という意味ではなく、
現行 tree 上の line provenance が squash / refactor 後の commit に寄っているためである。
個別の投入日・変更日は `00_legacy-repos` 側で追う必要がある。

---

## 主要参照

- `rocm-github-investigate.md`
- `provenance_map.md`
- `final_hypothesis.md`
- `support_boundary.md`

---

## 本文書が主張しないこと

- 社内意思決定や private issue の本文を断定するものではない
- 単一 component の履歴を ROCm 全体の universal rule とみなすものではない
- 後年の commit を直ちに「gfx900 の積極維持」と読むものではない
- 特定組織や個人への批判を目的とするものではない
