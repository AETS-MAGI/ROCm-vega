# ROCm 一般の設計思想に関する仮説検証メモ（GitHub 側検索）

更新日: 2026-03-15
対象: ROCm の GitHub repository / release note templates / issue / PR / discussion / 現行ソース

## 1. この文書の目的

この文書は、`gfx900` 個別調査から一段引いて、
**ROCm 一般の設計思想や保守モデルに関する仮説**を GitHub 側の情報で検証するためのメモである。

ここでいう GitHub 側の情報には、次を含む。

- 公開 repository の README / docs / changelog / code comment
- GitHub issue / PR / discussion の本文
- ローカル clone から追える commit history

主眼は次の問い:

- ROCm は monolithic な単一政策で動いているのか、それとも component ごとの局所最適なのか
- fallback / capability / deprecation は偶発的パッチか、設計パターンか
- support / build / runtime / driver / user space は同じ意味なのか
- AMD とコミュニティの役割はどの層で分かれるのか

本文書の目的は、公開一次資料およびローカル clone から観測可能な設計傾向・保守構造を整理することにある。AMD の意思決定を評価・批判するものではなく、非公開 issue や社内意思決定の内容を断定するものでもない。

---

## 2. 結論サマリ

- **仮説1: ROCm は layered / modular stack として自己定義している**
  - **supported**（公開一次資料の範囲で）
  - ROCm README 自体が、drivers / development tools / APIs を含む open-source stack と明記している。
  - さらに `HIP` を portability substrate とし、`default.xml` manifest と `repo` tool による multi-repo 管理を明示し、`TheRock` では CMake super-project を前面化している。

- **仮説2: hardware support は binary ではなく、component ごと・層ごとに分離している**
  - **strongly supported**（公開一次資料の範囲で）
  - release note、TheRock issue、support matrix 文脈から、build target / component support / user space / driver space は分離して扱われている。
  - さらに MIOpen 現行 tree では、MLIR solver 除外と並行して `gfx900` 向け runtime workaround や Find-db docs が残っており、solver / runtime metadata / docs の層差が可視化されている。

- **仮説3: capability-based selection と fallback は ROCm の中心設計のひとつ**
  - **strongly supported**（公開一次資料の範囲で）
  - Tensile docs と code が、individual architecture ID より capability を優先し、fallback catalog を正式概念として持っている。
  - rocBLAS も hipBLASLt -> Tensile、XF32 -> FP32 の fallback を明示実装している。

- **仮説4: ROCm は duplicated frontend / build knob を減らす方向へ進んでいる**
  - **supported**（公開一次資料の範囲で）
  - `HIPCC Perl scripts deprecation`、`Math libraries default to Clang instead of HIPCC`、`AMDGPU_TARGETS -> GPU_TARGETS`、`TheRock` の super-project 化、retired repo の統合先案内は、入口と repo topology の両方で統合圧力を示す。

- **仮説5: legacy support は削除より staged retreat で進む**
  - **supported**（公開一次資料の範囲で）
  - `gfx900` のような arch は source/runtime/path から即削除されるのではなく、default build からの後退、component ごとの exclusion、fallback 残存、そして一部 docs/runtime workaround 残存という段階的 legacy 化を辿る。

- **仮説6: public product layer が private backend constraint を吸収することがある**
  - **partially supported**（事例1件のみ確認）
  - `MIOpen` の `gfx900` MLIR disable は strong evidence だが、現時点では一般法則と断言するには事例が少ない。

- **仮説7: “コミュニティ維持か AMD 維持か” の二択は粗すぎる**
  - **supported as a framing, unresolved as a conclusion**
  - GitHub 側の材料は、投入主体・維持主体・運用主体・修正可能主体を分けて考える必要性をむしろ強く示している。

---

## 3. 調査範囲と限界

今回強く使った根拠:

- [ROCm/README.md](https://github.com/ROCm/ROCm)
- `ROCm/RELEASE.md`
- `ROCm/tools/autotag/templates/highlights/6.0.0.md`
- `ROCm/tools/autotag/templates/highlights/6.2.0.md`
- `rocblas/library/src/tensile_host.cpp`
- `Tensile/Tensile/Component.py`
- `Tensile/docs/src/conceptual/solution-selection-catalogs.rst`
- `TheRock/README.md`
- `00_legacy-repos/ROCR-Runtime/README.md`
- `00_legacy-repos/Tensile/README.md`
- `00_legacy-repos/vllm/README.md`
- `MIOpen/src/target_properties.cpp`
- `MIOpen/doc/src/embed.md`
- `MIOpen/doc/src/find_and_immediate.md`
- [ROCm/TheRock issue #1414](https://github.com/ROCm/TheRock/issues/1414)
- [ROCm/TheRock issue #1975](https://github.com/ROCm/TheRock/issues/1975)
- [ROCm/rocm-install-on-linux issue #648](https://github.com/ROCm/rocm-install-on-linux/issues/648)
- `MIOpen` の `gfx900` MLIR disable commit `2407d2f`

今回の限界:

- issue / PR 全体を網羅したわけではない
- private repository 側の議論は見えない
- maintainer の意図と結果論を完全には分離できない
- “community がどこまで支えているか” は GitHub issue だけでは不十分
- current `ROCm` repo では public release history の一部が `CHANGELOG.md` ではなく `RELEASE.md` と `tools/autotag/templates/*` に分散しており、旧 clone とファイル配置が一致しない

したがって、この文書は
**ROCm 一般の設計思想を完全に証明するものではなく、
GitHub 側の一次資料からどこまで強く言えるかを整理したもの**
として読むべきである。

---

## 4. 仮説別の検証

### 仮説1: ROCm は layered / modular stack として自己定義している

**判定**: supported

#### 仮説1の根拠

- `ROCm/README.md:3-5`
  - ROCm は drivers / development tools / APIs の collection と明記されている。
- `ROCm/README.md:12-16`
  - HIP を portability substrate として位置づけている。
- `ROCm/README.md:24-58`
  - `default.xml` manifest と `repo` tool による multi-repo source management を明示している。
- `TheRock/README.md:9-17`
  - `A CMake super-project for HIP and ROCm source builds` と `Tools for developing individual ROCm components` を掲げる。

#### 仮説1からの読み取り

- ROCm は単一ライブラリではなく、最初から多層 stack として自己記述されている。
- しかも build platform 自体も統合方向に再編されつつあり、stack 全体をまとめて扱う設計圧力がある。

#### 仮説1の含意

- `gfx900` のような個別 arch の生死を評価するときも、
  単一 repo の yes/no ではなく stack 全体の層ごとに見る必要がある。

---

### 仮説2: hardware support は binary ではなく、component ごと・層ごとに分離している

**判定**: strongly supported

#### 仮説2の根拠

- `MIOpen/src/target_properties.cpp:33,89-96`
  - `gfx900` に対する `sramecc-` misreport workaround が残っている。
- `MIOpen/doc/src/embed.md:32-36`
  - `gfx906_60;gfx900_56` と `-DMIOPEN_EMBED_DB=gfx900_56` を docs に記載。
- `MIOpen/doc/src/find_and_immediate.md:149-155`
  - system Find-Db populated architecture として `gfx900 with 64 CUs` / `gfx900 with 56 CUs` を記載。
- [ROCm/TheRock issue #1414](https://github.com/ROCm/TheRock/issues/1414)
  - unsupported target なのに hipBLASLt が default architecture で build される問題が議論されている。
- [ROCm/TheRock issue #1975](https://github.com/ROCm/TheRock/issues/1975)
  - component に supported GPU architecture が無い場合、super-project 側で除外すべきかが議論されている。
- [ROCm/rocm-install-on-linux issue #648](https://github.com/ROCm/rocm-install-on-linux/issues/648)
  - user space (ROCm) と driver version の split を明示すべきという論点が出ている。

#### 仮説2からの読み取り

- ROCm における “support” は一枚岩ではない。
- 少なくとも次が分かれている:
  - driver support
  - user-space / ROCm version support
  - component-level supported GPU targets
  - default build targets
  - runtime fallback path の残存

#### 仮説2の含意

- `非対応` という語を一語で使うと誤読しやすい。
- `gfx900` に限らず、ROCm 一般で support は layer-specific / component-specific に扱うべき。

---

### 仮説3: capability-based selection と fallback は ROCm の中心設計のひとつ

**判定**: strongly supported

#### 仮説3の根拠

- `Tensile/Tensile/Component.py:118-121`
  - “capability rather than based on individual architecture IDs.”
- `solution-selection-catalogs.rst:99-117`
  - fallback child catalog と architecture-specific fallback kernel が正式文書化されている。
- `rocblas/library/src/tensile_host.cpp:1161-1163`
  - `No Tensile solution found for XF32, fall back to FP32`
- `rocblas/library/src/tensile_host.cpp:1232-1239`
  - `hipBlasLT failed / exception encountered, falling back to tensile`

#### 仮説3からの読み取り

- fallback は偶発的な救済コードではなく、docs / catalog / runtime warning にまたがる設計要素。
- capability-based な選択と fallback catalog を持つことで、
  “速い最適経路” と “広く通る互換経路” を分離している。

#### 仮説3の含意

- `gfx900` の生存を「情けで残った」と読むより、
  capability / fallback 設計の副産物として残りやすいと読むほうが ROCm 一般の構造に合う。

---

### 仮説4: ROCm は duplicated frontend / build knob を減らす方向へ進んでいる

**判定**: supported

#### 仮説4の根拠

- `ROCm/RELEASE.md:497-499`
  - `HIPCC Perl scripts deprecation`
- `ROCm/tools/autotag/templates/highlights/6.2.0.md:79-85`
  - math libraries default compiler が `hipcc` から `amdclang++` に移る。
- `ROCm/tools/autotag/templates/highlights/6.0.0.md:795-798`
  - `GPU_TARGETS` を受け入れ、`AMDGPU_TARGETS` は backward compatibility 扱い。
- `TheRock/README.md:10-18`
  - ROCm source builds 向けの CMake super-project を掲げる。
- `00_legacy-repos/ROCR-Runtime/README.md:1-5`
  - retired; use `ROCm/rocm-systems`
- `00_legacy-repos/Tensile/README.md:1-6`
  - retired; use `ROCm/rocm-libraries`
- `00_legacy-repos/vllm/README.md:16-19`
  - retired; use upstream `vllm-project/vllm`

#### 仮説4からの読み取り

- ROCm は機能を増やす一方で、入口や build 変数、toolchain front door を減らす方向にも動いている。
- 同時に、standalone repo を `rocm-libraries` / `rocm-systems` / upstream へ寄せる repo-level consolidation も進んでいる。
- これは stack が大きくなるほど、利用者の入口を絞り、内部を整理したい圧力が強くなることを示す。

#### 仮説4の含意

- ROCm 一般の設計思想として、
  “表の入口は統合し、内部では component autonomy と capability/fallback を使う”
  という二層構造が見える。

---

### 仮説5: legacy support は staged retreat で進む

**判定**: supported

#### 仮説5の根拠

- `rocm-github-investigate.md` で確認した `Tensile 4.36.0`
  - `gfx900:xnack-` 追加記述がある。
- `rocm-github-investigate.md` で確認した hipCUB 4.0.0
  - `gfx803` / `gfx900` は default build から外れる。
- `MIOpen` commit `e5c6ce1` (2022-10-05)
  - MLIR 除外後も `gfx900` 向け runtime workaround と docs 例が残る。
- `rocm-github-investigate.md` で確認した MIOpen `2407d2f`
  - MLIR iGEMM では `gfx900` を product code 側で selective disable。

#### 仮説5からの読み取り

- ROCm の変更は、全削除よりも
  `新世代を追加` -> `旧世代を default から後退` -> `個別 component で exclusion` -> `fallback だけ残る`
  という段階で進みやすい。

#### 仮説5の含意

- `legacy 化` は source deletion ではなく、
  build / docs / runtime / support matrix の各層で速度差を伴って進む。

---

### 仮説6: public product layer が private backend constraint を吸収することがある

**判定**: partially supported

#### 仮説6の根拠

- `MIOpen` の `gfx900` MLIR disable commit `2407d2f`
  - public code 側では `gfx900` を disable
  - 根拠コメントは `llvm-project-private#389`

#### 仮説6からの読み取り

- 少なくとも 1 つの強い事例では、
  backend/compiler 側の問題が product code の gating として表面化している。
- ただし現時点では、これを ROCm 一般の常習パターンと断言するほど事例は集まっていない。

> `llvm-project-private#389` は非公開であり、本文は外部から確認できない。したがって、ここから言えるのは公開コード側に参照関係と gating の痕跡が存在するという範囲に限られる。

#### 仮説6の含意

- この仮説は維持するが、一般論として広げすぎない。
- 現時点では **“少なくとも MIOpen + gfx900 MLIR ではそうだった”** に留めるのが妥当。
- Miir API 実装が public であることは、コミュニティ側から gating 条件を読み取れる可能性を示す。

#### 仮説6の追加根拠（2026-03-15）

- 公開 `ROCm/rocMLIR` の `rocmlir-lib.cpp` から、Miir C API の実装全体を追跡できることを確認。
  - `miirCreateHandle`: `parseConvConfig` → `isApplicable` → `RockEnabled`（layout whitelist + bf16 exclusion）の多段検証。失敗時 `nullptr`。
  - `miirLowerTuningParams`: `rock::buildKernelPipeline`（`ApplicabilityMode::Applicability`）で pipeline 実行。失敗時 `MIIR_BUILD_FAILURE`。
  - MIOpen 側 `MiirIsConfigApplicable` は `miirLowerTuningParams` の `MIIR_SUCCESS` 判定のみ。
- gating メカニズム側は public に追跡可能。ただし `#389` が具体的にどの compilation failure を指しているかは依然不明。
- gating の実装は public（rocMLIR）だが、gating の根拠となった問題（#389）は非公開のままである。

### 仮説7: “コミュニティ維持か AMD 維持か” の二択は粗すぎる

**判定**: supported as a framing, unresolved as a conclusion

#### 仮説7の根拠

- TheRock issue 群は、support 問題が super-project / component metadata / build matrix の層に分かれていることを示す。
- `rocm-install-on-linux#648` は、driver と user-space を同一視すると混乱が起きることを示す。
- `MIOpen 2407d2f` は投入主体の一部が AMD であることを強く示す。
- しかしこれだけでは、維持主体・運用主体・修正可能主体は決まらない。

#### 仮説7からの読み取り

- 少なくとも次は分けるべき:
  - 投入主体
  - 維持主体
  - 運用主体
  - 修正可能主体

#### 仮説7の含意

- `gfx900` の出来事だけ見て
  “ROCm はコミュニティ維持ではない”
  と言い切るのは早い。
- より正確には、
  **AMD 起点の重要分岐 + capability/fallback 設計の残存 + コミュニティによる運用・知見共有**
  の重なりとして捉えるべき。

---

## 5. reveal された設計モデル（暫定）

GitHub 側の材料から見える ROCm 一般の設計モデルを、あえて短くまとめると次のようになる。

補足（2026-03-15）:

- `ROCm/MIOpen#1231` の public 文脈は、community user が直面した COMGR target-name failure を userspace workaround で吸収する層が存在することを示す。
- `ROCm/MIOpen#1328` の public 文脈は、private root cause を抱えたまま ROCm 5.1 の MLIR release / tuning surface から `gfx900` を外す判断が行われたことを示す。
- したがって、同一 component 内でも **public issue-driven workaround** と **private-rooted release gating** が別の層として共存しうる。

1. ROCm は layered open stack として自己定義されている。
2. build / runtime / support matrix / driver / user space は同じ意味ではない。
3. component ごとに supported targets と exclusion policy はずれる。
4. execution path は capability-based selection と fallback で広く支えられる。
5. 表の入口や build knob は徐々に統合される。
6. legacy は source から即時に消えるのでなく、段階的に retreat する。
7. 同一 component 内でも public issue-driven workaround と private-rooted release gating が併存しうる。
8. 保守主体は単一ではなく、少なくとも投入・維持・運用・修正可能性に分解して考える必要がある。

---

## 6. まだ言い切れないこと

- ROCm maintainer が明示的に「この思想で設計した」と語っている一次資料はまだ不足している。
- community がどの層まで実質的に支えているかは、issue / PR / workaround 文書の追加調査が必要。
- private backend issue が public gating に反映される例が一般的かどうかは未確定。
- `#1231` と `#1328` の public 文脈は回収できたが、後者の private root cause 自体はなお非公開である。
- UDNA や将来統合との接続は、構造的推測としては筋がよいが、現時点では直接証拠が薄い。

---

## 7. 現時点の暫定結論

ROCm 一般の設計思想について、GitHub 側の一次資料から比較的強く言えるのは次である。

- ROCm は monolith ではなく layered / modular stack である。
- support は binary ではなく、component ごと・層ごとに分離している。
- capability-based selection と fallback は中心的な設計パターンである。
- stack が広がる一方で、build / compiler / frontend の入口は統合方向に整理されている。
- legacy support は staged retreat として進みやすい。

したがって、`gfx900` は特殊な例外というより、
ROCm が本来持っている layered support / fallback / staged deprecation の構造を可視化しやすい観測点
として理解するのが最も自然である。

---

## 8. 本文書が主張しないこと

以下は、本文書の記述から意図的に除外している主張である。

- ROCm maintainer が明示的にこの設計思想を意図していたと断定するものではない
- `llvm-project-private#389` の内容を推定で補完するものではない
- 本文書で言及した仮説が ROCm 全体の一般法則として確定しているとするものではない
- AMD の support policy 全体を完全に代表するものではない
- AMD またはコミュニティのいずれかが単独で全体を制御していると断定するものではない
- AMD または特定個人への批判を意図するものではない

---

## 9. 追跡に使った主な根拠

### ローカル clone

- `ROCm/README.md:3-58`
- `ROCm/RELEASE.md:497-499`
- `ROCm/tools/autotag/templates/highlights/6.0.0.md:795-798`
- `ROCm/tools/autotag/templates/highlights/6.2.0.md:79-85`
- `TheRock/README.md:9-18`
- `MIOpen/src/target_properties.cpp:33,89-96`
- `MIOpen/doc/src/embed.md:32-36`
- `MIOpen/doc/src/find_and_immediate.md:149-155`
- `Tensile/Tensile/Component.py:118-121`
- `Tensile/docs/src/conceptual/solution-selection-catalogs.rst:95-117`
- `rocblas/library/src/tensile_host.cpp:1161-1163`
- `rocblas/library/src/tensile_host.cpp:1232-1239`

### GitHub issues / discussions

- [ROCm/TheRock issue #1414](https://github.com/ROCm/TheRock/issues/1414)
- [ROCm/TheRock issue #1975](https://github.com/ROCm/TheRock/issues/1975)
- [ROCm/rocm-install-on-linux issue #648](https://github.com/ROCm/rocm-install-on-linux/issues/648)
- [ROCm/MIOpen commit `2407d2f556c7`](https://github.com/ROCm/MIOpen/commit/2407d2f556c7635de3f4b3f009681bdd92ba82e2)
