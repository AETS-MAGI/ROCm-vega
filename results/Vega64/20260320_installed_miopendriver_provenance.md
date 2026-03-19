# 2026-03-20 installed MIOpenDriver provenance follow-up

## 概要

2026-03-19 までの追補で、
local Debug `MIOpenDriver` の legacy-style `convint8` 挙動は
`miopen-src@f842c61d` 由来だと分かった。

今回の follow-up では、
普段使っている installed `/opt/rocm/bin/MIOpenDriver`
そのものの provenance を、

- package ownership
- embedded debug/source path
- installed header / library version
- local clone との source-level 比較

から絞り込む。

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 1. 問い

2026-03-19 時点では、少なくとも次が分かっていた。

- current public standalone `ROCm-repos/MIOpen` は
  INT8 output を `miopenInt32` descriptor で表現する
- local Debug `MIOpenDriver` は
  `miopen-src@f842c61d` 由来で、
  cast-aware `--out_cast_type` path を保持していた
- installed `/opt/rocm/bin/MIOpenDriver` も
  help / runtime の範囲では legacy-style cast flag を見せていた

ここで残る問いは、
**この host 上の installed `/opt/rocm/bin/MIOpenDriver` が、
どの lineage の source tree に近いか**
である。

---

## 2. Fact

### 2.1 installed binary は Arch package `miopen-hip 7.2.0-1` に属する

- `pacman -Qo /opt/rocm/bin/MIOpenDriver`
  は
  `miopen-hip 7.2.0-1`
  を返す
- `pacman -Qi miopen-hip`
  では、
  build date は `2026-01-30 18:08:44`
  packager は `Torsten Keßler`
  と記録されている

したがって、
少なくともこの host の installed `MIOpenDriver` は
**distro package として配布された binary**
であり、
ここから直ちに「AMD 公式 binary の provenance 一般」を述べることはできない。

### 2.2 binary / library の埋め込み path は `rocm-libraries/projects/miopen` を指す

- `strings -a /opt/rocm/bin/MIOpenDriver`
  には
  `/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/driver/conv_driver.hpp`
  などの path が埋め込まれている
- 同 binary には
  `out_cast_type`, `in_cast_type`, `wei_cast_type`
  も現れる
- `strings -a /opt/rocm/lib/libMIOpen.so`
  にも
  `/usr/src/debug/miopen-hip/rocm-libraries/projects/miopen/src/...`
  という path が多数現れる

したがって、
少なくとも installed package の build/debug path は
**`rocm-libraries/projects/miopen` 形式の source tree**
を指している。

### 2.3 installed package は `MIOpen 3.5.1.5b515cf1bca-dirty` を名乗る

- `/opt/rocm/include/miopen/version.h` では
  `MIOPEN_VERSION_MAJOR 3`
  `MIOPEN_VERSION_MINOR 5`
  `MIOPEN_VERSION_PATCH 1`
  `MIOPEN_VERSION_TWEAK 5b515cf1bca-dirty`
  が定義されている
- `strings -a /opt/rocm/lib/libMIOpen.so`
  にも
  `MIOpen version 3.5.1.5b515cf1bca-dirty`
  が現れる

したがって、
少なくとも installed package 全体は
**3.5.1 系の configured source tree**
から作られている。

### 2.4 installed `MIOpenDriver` の surface behavior は cast-aware path と整合する

- `MIOpenDriver convint8 --help`
  には
  `--in_cast_type`, `--wei_cast_type`, `--out_cast_type`
  が出る
- 2026-03-18 の runtime follow-up では、
  `--out_cast_type int32`
  は token として reject され、
  `--out_cast_type fp32`
  は accept されるが
  `...INT8-F_coFP32`
  の別 problem へ寄ることを確認した

したがって、
installed driver の observed behavior は
**cast-aware driver family**
と整合する。

### 2.5 current public standalone `ROCm-repos/MIOpen` は installed package と直接一致しない

- current public standalone
  `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/CMakeLists.txt`
  は
  `cmake_minimum_required(VERSION 3.5)`,
  `add_compile_options(-std=c++14)`,
  `rocm_setup_version(VERSION 2.18.0)`
  を持つ
- 同 clone の
  `driver/conv_driver.hpp`
  には
  `out_cast_type` 系の validation は現れず、
  INT8 output は
  `y_type = miopenInt32`
  に切り替えられる

したがって、
少なくともこの installed package を
**current public standalone `ROCm-repos/MIOpen` の直接 build**
として読むのは安全ではない。

### 2.6 local clones のうち、installed package に近いのは `rocm-libraries/projects/miopen` / `miopen-src` 側である

- local `rocm-libraries` git object の
  `projects/miopen/driver/conv_driver.hpp`
  には
  `out_cast_type` 系 validation と
  `miopenSetTensorCastType(outputTensor, out_cast_type)`
  が残っている
- 同 tree の
  `projects/miopen/CMakeLists.txt`
  は
  `cmake_minimum_required(VERSION 3.15)`,
  `CMAKE_CXX_STANDARD 17`,
  `rocm_setup_version(VERSION 3.4.0)`
  を持つ
- `miopen-src/driver/conv_driver.hpp`
  も同様に cast-aware path を保持し、
  `miopen-src/CMakeLists.txt`
  は
  `cmake_minimum_required(VERSION 3.15)`,
  `CMAKE_CXX_STANDARD 20`,
  `rocm_setup_version(VERSION 3.5.1)`
  を持つ

したがって、
installed package の

- embedded path (`rocm-libraries/projects/miopen`)
- cast-aware driver behavior
- `3.5.1.*` version macro

を合わせて読むと、
**current standalone clone よりも、
`rocm-libraries/projects/miopen` / `miopen-src` 側の family に近い**
と少なくとも言える。

---

## 3. Interpretation

- この host の installed `/opt/rocm/bin/MIOpenDriver` は、
  少なくとも
  **current public standalone `ROCm-repos/MIOpen` の直接 build ではない**
  と読める
- embedded debug/source path は
  `rocm-libraries/projects/miopen`
  を指し、
  surface behavior は cast-aware driver family と整合するため、
  installed package は
  **rocm-libraries/projects/miopen-style source tree**
  に強く寄っていると読むのが自然である
- 一方で、
  installed `version.h` の `3.5.1.5b515cf1bca-dirty`
  は local `miopen-src` の version lineage に近く、
  local `rocm-libraries` HEAD の `3.4.0` とは一致しない
- したがって、
  local evidence から最も安全に言えるのは、
  **installed package は `rocm-libraries/projects/miopen` family の cast-aware tree に寄るが、
  exact source commit / exact packaging tree まではまだ閉じていない**
  という範囲である
- また、
  この binary は Arch package `miopen-hip 7.2.0-1`
  に属するため、
  ここから AMD 公式配布物一般の provenance を断定することも避けるべきである

---

## 4. 少なくともここまでは言える

- current public standalone `ROCm-repos/MIOpen`
  と installed `/opt/rocm/bin/MIOpenDriver`
  を 1:1 に対応づけるのは安全ではない
- local Debug `MIOpenDriver` だけでなく、
  installed `MIOpenDriver` も
  **cast-aware driver family**
  に寄っている
- ただし、
  local Debug binary は `miopen-src@f842c61d` と source root まで確定できたのに対し、
  installed binary は
  **package ownership / embedded path / configured version**
  の範囲までしか閉じていない
- したがって、
  `MIOpenDriver convint8` の INT8 境界を論じるときは、
  少なくとも次を分けて扱う必要がある
  - current public standalone clone
  - local debug build (`miopen-src@f842c61d`)
  - this host の installed distro package (`miopen-hip 7.2.0-1`)

---

## 5. Open Question / Limitation

1. `5b515cf1bca-dirty` が local clone のどの exact source state に対応するかは未確認
2. Arch package `miopen-hip 7.2.0-1` の build source commit / packaging tree は、local evidence だけでは確定できない
3. `installed /opt/rocm/bin/MIOpenDriver` が direct `y=int32` route を CLI からどう表現し損ねるかは、なお driver option / descriptor assembly 側の別問いとして残る
4. したがって、installed package の provenance を「miopen-src そのもの」または「rocm-libraries HEAD そのもの」と断定することはできない

---

## 6. 判定

`confirmed_partial`

少なくともこの host の installed `/opt/rocm/bin/MIOpenDriver` は、
current public standalone `ROCm-repos/MIOpen`
よりも
`rocm-libraries/projects/miopen` 系の cast-aware driver family
に近い。
ただし、exact source commit は未確定である。

---

## 7. 根拠リンク

- `/opt/rocm/bin/MIOpenDriver`
- `/opt/rocm/lib/libMIOpen.so`
- `/opt/rocm/include/miopen/version.h`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/CMakeLists.txt`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-libraries` (git object)
- `/home/limonene/ROCm-project/WD-Black/miopen-src/CMakeLists.txt`
- `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/conv_driver.hpp`

---

## 本文書が主張しないこと

- AMD 公式 binary 配布物一般の provenance を断定するものではない
- Arch package `miopen-hip 7.2.0-1` の build script 全体を再構成したものではない
- `5b515cf1bca-dirty` の exact upstream commit を確定したものではない
- 社内意思決定や private issue の内容を推定するものではない
- 特定組織や個人への批判を目的とするものではない
