# ROCm 一般の設計思想と GitHub 上の寄与構造に関する調査メモ

更新日: 2026-03-15
対象:

- local clone: `/home/limonene/ROCm-project/WD-Black/ROCm-repos/`
- public GitHub issue / PR: 2026-03-15 時点で `gh` 経由により確認した範囲

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

## 1. この文書の目的

この文書は、`gfx900` 個別事例から一段引いて、
**ROCm 全体の設計思想と、GitHub 上で見える AMD / community の寄与構造**
を整理するための investigation note である。

主眼は次の 3 点:

- ROCm が GitHub 上でどのように自己定義されているか
- support / build / runtime / repo topology がどのように分離して見えるか
- AMD と community の寄与が、どの層でどのように現れているか

## 2. 調査範囲と限界

### 2.1 今回使った主な根拠

- `ROCm/README.md`
- `ROCm/RELEASE.md`
- `ROCm/tools/autotag/templates/highlights/6.0.0.md`
- `TheRock/README.md`
- `rocm-systems/README.md`
- `00_legacy-repos/ROCR-Runtime/README.md`
- `00_legacy-repos/Tensile/README.md`
- `00_legacy-repos/vllm/README.md`
- `ROCm/TheRock#1414`
- `ROCm/TheRock#1975`
- `ROCm/rocm-install-on-linux#648`
- `ROCm/Tensile#1595`
- `ROCm/Tensile#1862`

### 2.2 限界

- live な GitHub 全量を統計的に集計したわけではない。
- private repository 側の議論は見えない。
- GitHub の `authorAssociation` は、雇用関係そのものを表すものではない。
- したがって、ここで述べる「AMD の寄与」「community の寄与」は、**観測できた寄与の層**を指すのであって、全体比率や最終責任分担を断定するものではない。

## 3. ROCm は GitHub 上で layered / multi-repo stack として自己定義されている

### Fact

- `ROCm/README.md` 冒頭は、ROCm を
  drivers / development tools / APIs からなる open-source stack と記述している。
- 同 README は `default.xml` manifest と `repo` tool を前面に出し、
  source checkout 自体を multi-repo operation として説明している。
- `git blame` 上で、この README 冒頭ブロックは
  commit `65b84988671bc76c7975556a3d79a7bb42de78e2`
  （`ammallya <ameyakeshava.mallya@amd.com>`）由来である。
- `TheRock/README.md` は TheRock を
  `A CMake super-project for HIP and ROCm source builds`
  と説明し、
  ROCm contributors / developers / researchers / advanced users を対象にし、
  `welcomes contributors` と明記している。
- `git blame` 上で、この TheRock README 冒頭ブロックは
  commit `1408a826dc2c3446a0295c0ef0c71c4d92f0f4f9`
  （`Geo Min <geomin12@amd.com>`）由来である。
- `rocm-systems/README.md` は
  `ROCm Systems super-repo`
  として、複数 project を単一 repository に集約し、
  `streamline development, CI, and integration`
  を掲げている。
- 同 README は各 component ごとに
  `Source of Truth` / `Migration Status` / `CI Status`
  を表で明示し、old repo から super-repo への移行段階を公開している。

### Interpretation

- ROCm は GitHub 上で、単一 monolith というより
  **layered stack + multi-repo source set + super-project / super-repo**
  として自己記述されている。
- しかも `ROCm` root repo、`TheRock`、`rocm-systems` はそれぞれ
  release manifest、build platform、systems monorepo という別の役割を持っており、
  GitHub 上の repository topology 自体が層化している。

### Open Question / Limitation

- `rocm-libraries` 側の umbrella 方針は、今回 local snapshot では working tree 展開が薄く、README ベースでは十分追えていない。
- よって monorepo / umbrella 化の全体像は、systems 側ほど均一にはまだ言い切れない。

## 4. support は build / component / user space / driver で分離して見える

### Fact

- `ROCm/TheRock#1414`
  - author: `umarinkovic`
  - title: `Completely skipping the building of hipBLASLt for targets that don't support it`
  - issue body は、unsupported target でも hipBLASLt が default architecture で build されることを問題にしている。
  - comment では `marbre` (`MEMBER`) が `@stellaraccident` と `@amd-chrissosa` に確認を促している。
- `ROCm/TheRock#1975`
  - author: `bstefanuk`
  - title: `Mechanism to omit rocm-libraries components when the requested GPU target is unsupported`
  - issue body は、super-project 側で target が空になっても component 側 default target に fall back してしまい、
    incompatible binaries を含む package が生成される問題を整理している。
- `ROCm/rocm-install-on-linux#648`
  - author: `LaVLaS`
  - title: `Add "user space (ROCm)" annotation to documentation introducing the split between driver and user space versions`
  - issue body は、driver version と user-space / ROCm version の split が利用者に混乱を生むことを指摘している。
  - comment では `harkgill-amd` (`CONTRIBUTOR`) が、変更案の PR を起こしたと応答している。

### Interpretation

- GitHub issue 群から見える `support` は一語では足りず、少なくとも次に分かれている。
  - super-project build matrix support
  - component-level supported GPU targets
  - package contents の整合性
  - driver version と user-space / ROCm version の対応
- これらは `gfx900` に限らない ROCm 一般の構造であり、TheRock や install docs の issue はその分離を public に可視化している。

### Open Question / Limitation

- これらの issue が individual reports なのか recurring pattern なのかは、さらに issue を増やして見ないと断定できない。

## 5. official 側では build entry point と repo topology の統合が進んでいる

### Fact

- `ROCm/RELEASE.md` には
  `HIPCC Perl scripts deprecation`
  が upcoming change として記載されている。
- `ROCm/tools/autotag/templates/highlights/6.0.0.md` では
  `GPU_TARGETS` が `AMDGPU_TARGETS` に代わる preferred knob として扱われている。
- retired / legacy repo README には、それぞれ次の移行先が明記されている。
  - `ROCR-Runtime` -> `ROCm/rocm-systems`
  - `Tensile` -> `ROCm/rocm-libraries`
  - `ROCm/vllm` -> upstream `vllm-project/vllm`
- retired marker commit の metadata は次の通り。
  - `ROCR-Runtime`: `ba56a24c6132...`, `Joseph Macaranas <145489236+jayhawk-commits@users.noreply.github.com>`
  - `Tensile`: `c5c240220d03...`, `ammallya <ameyakeshava.mallya@amd.com>`
  - `ROCm/vllm`: `eb9d4de9eb76...`, `Gregory Shtrasberg <Gregory.Shtrasberg@amd.com>`
- `rocm-systems/README.md` は、super-repo 側を `source of truth` にする component を表で明示している。

### Interpretation

- ROCm の public GitHub record からは、
  **frontend / build knob の統合** と
  **repository topology の再編**
  が同時に進んでいるように見える。
- これは、stack の拡大に対して入口と責務配置を整理しようとする動きとして読める。

### Open Question / Limitation

- repo consolidation が最終的にどこまで進むか、また `rocm-libraries` 側でどの程度 source-of-truth 化が進むかは、現時点では repo ごとに温度差がある。

## 6. GitHub 上で見える寄与は「AMD vs community」の二択ではなく層ごとに違う

### 6.1 user-originated issue / discussion の層

#### Fact

- `TheRock#1414` は `umarinkovic` による起票で、unsupported arch に対する hipBLASLt build behavior の曖昧さを問題化している。
- `TheRock#1975` は `bstefanuk` による起票で、unsupported target 時に component を build matrix から外すべきかを整理している。
- `rocm-install-on-linux#648` は `LaVLaS` による起票で、driver / user-space split の documentation ambiguity を指摘している。

#### Interpretation

- public GitHub 上で user / community 側が担っている寄与のひとつは、
  **support boundary の曖昧さを発見し、論点として可視化すること**
  だと読める。
- これは implementation を直接書く層とは別の、運用・観測・問題設定の寄与である。

### 6.2 external PR / source-build / fallback 補修の層

#### Fact

- `ROCm/Tensile#1595`
  - title: `Add gfx900:xnack-, gfx1032, gfx1034, gfx1035`
  - author: `cgmb`
  - public body には
    `official binaries distributed by AMD` 向けではなく
    `users building from source` 向けだと明記されている。
  - commit author email は `Cordell.Bloor@amd.com` であり、
    §2.2 で述べたとおり GitHub の `authorAssociation` が組織所属を直接表すものではないことを示す具体例となっている。
- `ROCm/Tensile#1862`
  - title: `Use fallback libraries for archs without optimized logic`
  - author: `GZGavinZhao`
  - body は、optimized logic がない architecture でも fallback library を生成し、
    rocBLAS が source build で動くようにする修正を説明している。
  - test plan には `gfx803;gfx900;...;gfx1102` が含まれる。
  - review では `AlexBrownAMD` (`COLLABORATOR`) が
    `External PR review summary` として承認している。
  - comment thread では `hiepxanh` や `userbox020` など public user が merge / runtime availability を強く求めている。

#### Interpretation

- library fallback / source-build 実用性の層では、
  **external contributor が patch を持ち込み、official maintainer / collaborator が review・merge する**
  という協働構造が見える。
- ここでは community の寄与は、単なる issue 起票に留まらず、
  source-build viability や fallback availability を直接改善する code contribution としても観測される。

#### Open Question / Limitation

- `authorAssociation` は GitHub 上の権限関係を示すに留まり、AMD 所属かどうかを直接表すものではない。
- したがって、この層を「外部だけ」「AMD だけ」と単純化するのは危険である。

### 6.3 official docs / release / super-project 整理の層

#### Fact

- `ROCm/README.md`、`TheRock/README.md`、`rocm-systems/README.md` の現行冒頭ブロックは、
  official repo の current tree においてそれぞれ異なる commit 由来で維持されている。
- `ROCm/RELEASE.md` や highlight templates は、upcoming change と release guidance を official に公開している。
- retired marker や super-repo migration table は、public tree 側で明示的に管理されている。

#### Interpretation

- build platform、release note、repo consolidation、source-of-truth migration の層では、
  **official maintainers / AMD-affiliated authors が visible な整理役**
  を担っているように見える。
- この層の寄与は、利用者の入口や CI / integration topology を整える方向に集中している。

## 7. 暫定的な層分解

現時点の GitHub-side evidence から、寄与の構造を単純化しすぎずに書くなら次の表が妥当である。

| 層 | 主な観測根拠 | 見えている寄与 |
|---|---|---|
| 自己定義 / release / build platform | `ROCm/README.md`, `TheRock/README.md`, `rocm-systems/README.md`, `RELEASE.md` | official repo 側での stack 定義、release guidance、super-project / super-repo 整理 |
| support 境界の発見 | `TheRock#1414`, `TheRock#1975`, `rocm-install-on-linux#648` | user-originated issue による build/support ambiguity の可視化 |
| source-build / fallback 補修 | `Tensile#1595`, `Tensile#1862` | contributor patch + maintainer review による fallback / portability 改善 |
| repo topology 再編 | retired README, `rocm-systems/README.md` | official 側の責務再配置、source of truth の移動 |

## 8. 現時点の暫定結論

### Fact

- ROCm は GitHub 上で layered open stack / multi-repo source set として自己定義されている。
- TheRock と rocm-systems は、build と integration を umbrella 化する official な動きとして見える。
- support を巡る public issue は、build matrix / component support / driver-user-space split が別問題であることを示している。
- source-build / fallback の一部では、external contributor の patch と official maintainer の review が共存している。

### Interpretation

- ROCm の GitHub 上の寄与構造は、
  **AMD が全部を直接担う** でも
  **community だけが支えている** でもなく、
  層ごとに役割が違うように見える。
- 少なくとも観測できる範囲では、
  - official 側は self-definition / release / super-project / repo consolidation を強く担う
  - public user / contributor 側は support-boundary の発見、source-build 実用性、fallback 補修で強く現れる
  と読むのが妥当である。

### Open Question / Limitation

- これは定量的な contribution share ではない。
- さらに多くの repo / PR / discussion を追わない限り、ROCm 全体への一般化は慎重であるべき。
- 特に GitHub の visible surface に出てこない private planning / internal review は、ここからは見えない。

## 9. 本文書が主張しないこと

以下は、本文書の記述から意図的に除外している主張である。

- AMD の社内意思決定過程を断定するものではない
- GitHub 上の `authorAssociation` から雇用関係を断定するものではない
- 一部の issue / PR から ROCm 全体の contribution ratio を確定するものではない
- 特定組織または特定個人への批判を目的とするものではない
- private issue や internal review の内容を推定で補完するものではない
