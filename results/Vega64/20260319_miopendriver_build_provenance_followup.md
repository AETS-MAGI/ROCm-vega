# 2026-03-19 MIOpenDriver INT8 build provenance follow-up

## 概要

`MIOpenDriver convint8` の挙動を current public `ROCm-repos/MIOpen` source と照らすと、
一見すると source-level の descriptor split と runtime 観測が食い違って見える。

今回の追補では、local debug build の provenance を確認し、
**cross-check に使っていた debug `MIOpenDriver` 自体が、
current public clone ではなく別 checkout (`/home/limonene/ROCm-project/WD-Black/miopen-src`) から
ビルドされていた**
ことを固定する。

この follow-up により、
「current public `conv_driver.hpp` は `y=int32` route を表現しているのに、
local debug `MIOpenDriver` はなぜ legacy-style cast flag を出し続けるのか」
という食い違いは、少なくとも **build provenance の差** で一段説明できる。

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 1. 問い

2026-03-18 時点で、次の食い違いが残っていた。

- current public standalone `ROCm-repos/MIOpen/driver/conv_driver.hpp` では、
  `convint8` の output tensor は `miopenInt32` へ切り替えられる
- しかし local debug build の `MIOpenDriver convint8 --help` には、
  なお `--in_cast_type` / `--wei_cast_type` / `--out_cast_type` が見えていた
- さらに同 debug build で `convint8` を実行すると、
  problem key は `...-INT8-F` に見え、
  current public source から期待される `...-INT8INT8INT32-F`
  と一致しなかった

この差が
「current source を読んでも runtime を説明できない」問題なのか、
それとも **cross-check に使った binary の provenance が別だった** のかを切り分ける。

---

## 2. Fact

### 2.1 local debug build は `miopen-src` checkout から作られていた

- local debug build directory
  `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-build-20260314_135541/CMakeCache.txt`
  には、
  `MIOpen_SOURCE_DIR:STATIC=/home/limonene/ROCm-project/WD-Black/miopen-src`
  が記録されている
- 同 build tree の `CMAKE_HOME_DIRECTORY` も
  `/home/limonene/ROCm-project/WD-Black/miopen-src`
  を指している
- したがって、2026-03-14 に作った debug `MIOpenDriver` は
  `ROCm-repos/MIOpen` ではなく、
  別 checkout の `miopen-src`
  を source root としてビルドされていた

### 2.2 built binary 自体も `miopen-src` を参照している

- local debug build の
  `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-prefix-20260314_135541/bin/MIOpenDriver`
  に対して `strings` を取ると、
  `out_cast_type`, `in_cast_type`, `wei_cast_type`
  が現れる
- 同じ binary からは
  `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/dm_convint8.cpp`
  という source path 文字列も確認できる
- したがって、
  local debug `MIOpenDriver`
  が `miopen-src` 側の driver 実装を含むことは、
  少なくとも binary 文字列の範囲でも確認できる

### 2.3 `miopen-src` checkout は detached HEAD だった

- `/home/limonene/ROCm-project/WD-Black/miopen-src`
  の `git status --short --branch` は
  `## HEAD (no branch)`
  を返す
- `git rev-parse HEAD` は
  `f842c61d79700b7078924c52dffb697c7d997460`
  を返す
- remote は `https://github.com/ROCm/MIOpen.git`
  を向いている

### 2.4 `miopen-src` の driver は cast-aware path を保持している

- `miopen-src/driver/conv_driver.hpp`
  には、
  `valid_cast_types = {"fp32", "fp16", "bf16", "fp8", "bf8"}`
  と
  `in_cast_type` / `wei_cast_type` / `out_cast_type`
  の validation が残っている
- `miopen-src/driver/conv_driver.hpp` の `GetandSetData()` では、
  output tensor は
  `SetTensorNd(outputTensor, out_len, ..., data_type)`
  で作られ、
  その後で必要なら
  `miopenSetTensorCastType(outputTensor, out_cast_type)`
  が呼ばれる
- これは 2026-03-18 に比較した
  `00_legacy-repos/MIOpen/driver/conv_driver.hpp`
  の cast-aware path と整合的である

### 2.5 current public standalone `ROCm-repos/MIOpen` は別 path になっている

- current public standalone
  `ROCm-repos/MIOpen/driver/conv_driver.hpp`
  では、
  `out_cast_type` 系の validation は見当たらない
- 同 file の `GetandSetData()` では、
  `data_type == miopenInt8 || data_type == miopenInt8x4`
  のとき
  `y_type = miopenInt32`
  を作って
  `SetTensorNd(outputTensor, ..., y_type)`
  に渡している
- つまり current public standalone は、
  local debug build 元の `miopen-src`
  とは別の INT8 output-descriptor path を持つ

---

## 3. Interpretation

- 2026-03-18 まで残っていた
  「current public source は `y=int32` path なのに、
  local debug `MIOpenDriver` は legacy-style cast flag を出す」
  という食い違いは、
  少なくとも **local debug build が別 checkout (`miopen-src@f842c61d`) から作られていた**
  ことで一段説明できる
- したがって、
  local debug `MIOpenDriver` の legacy-style 挙動を、
  そのまま current public `ROCm-repos/MIOpen`
  の runtime representative とみなすのは安全ではない
- 一方で、
  installed `/opt/rocm/bin/MIOpenDriver`
  も help / strings の範囲では
  同じ cast-aware UI 断片を見せる
  (`out_cast_type`, `in_cast_type`, `wei_cast_type`)
  ため、
  少なくとも **surface behavior** は
  `miopen-src` 側の driver family と整合的に見える
- ただし、
  このことだけで installed binary の build provenance まで
  断定することはできない

---

## 4. 少なくともここまでは言える

- local debug `MIOpenDriver` と current public standalone `ROCm-repos/MIOpen`
  の食い違いは、
  単なる読み違いではなく、
  **source root 自体が違っていた**
  ことで説明できる
- current public standalone `ROCm-repos/MIOpen` の `y=int32` route と、
  `miopen-src@f842c61d` の cast-aware `convint8` route は
  同一ではない
- したがって、
  `MIOpenDriver convint8` の INT8 境界を議論するときは、
  **current public source**, **local debug build provenance**, **installed binary behavior**
  を分けて扱う必要がある

---

## 5. Open Question / Limitation

1. installed `/opt/rocm/bin/MIOpenDriver` が
   `miopen-src` と同系統の source からビルドされたかは未確認
2. `miopen-src@f842c61d` が public `ROCm/MIOpen` のどの lineage に属するか、
   また current public standalone `ROCm-repos/MIOpen` と
   いつ分岐したかは未整理
3. したがって、
   `installed driver の provenance` と
   `current public tree との差分理由`
   を完全に閉じたわけではない

---

## 6. 判定

`confirmed`

少なくとも local debug `MIOpenDriver` の cast-aware 挙動は、
current public standalone `ROCm-repos/MIOpen`
ではなく、
別 checkout `miopen-src@f842c61d`
からビルドされていた事実と整合する。

---

## 7. 根拠リンク

- `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-build-20260314_135541/CMakeCache.txt`
- `/home/limonene/ROCm-project/WD-Black/rocm-builds/miopen-debug-prefix-20260314_135541/bin/MIOpenDriver`
- `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/dm_convint8.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/conv_driver.hpp`

---

## 本文書が主張しないこと

- installed `/opt/rocm/bin/MIOpenDriver` の build provenance を断定するものではない
- `miopen-src@f842c61d` の upstream lineage を確定するものではない
- current public standalone `ROCm-repos/MIOpen` が
  直ちに installed binary と一致すると断定するものではない
- 特定組織や個人への批判を目的とするものではない
