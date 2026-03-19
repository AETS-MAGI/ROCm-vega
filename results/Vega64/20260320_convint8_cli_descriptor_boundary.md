# 2026-03-20 convint8 CLI descriptor boundary follow-up

## 概要

2026-03-18 までの follow-up で、

- direct `x=int8, w=int8, y=int32` descriptor は
  `solution_id = 89` を露出し、
  direct immediate / standard `Find + Forward` の両方で成功する
- installed `MIOpenDriver convint8 --out_cast_type fp32` は
  `...INT8-F_coFP32` の別 problem に寄り、
  direct `y=int32` route の代替にならない
- installed `/opt/rocm/bin/MIOpenDriver` は
  current standalone clone より
  `rocm-libraries/projects/miopen` 系 cast-aware family に近い

ことまでは整理できていた。

今回の follow-up では、
**installed `MIOpenDriver convint8` の option surface 自体が、
current standalone source の direct `y=int32` route を
どう見せているか / 見せていないか**
を source と CLI の両方から絞る。

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## 1. 問い

残っている問いは次だった。

- `convint8` CLI は current standalone source の
  direct `y=int32` route を「知っていない」のか
- それとも parser / descriptor assembly のどこかで
  legacy cast-aware path に丸めているのか

この差を切るには、

1. `convint8` entrypoint 自体
2. output descriptor の組み立て方
3. installed CLI が expose している option surface

を分けて見る必要がある。

---

## 2. Fact

### 2.1 `convint8` entrypoint 自体は `ConvDriver<int8_t, int32_t>`

- current standalone
  `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/main.cpp`
  では、
  `base_arg == "convint8"` の分岐で
  `new ConvDriver<int8_t, int32_t>()`
  を返す
- local `miopen-src/driver/dm_convint8.cpp` も
  `new ConvDriver<int8_t, int32_t>()`
  を返す
- local `rocm-libraries` git object
  `projects/miopen/driver/dm_convint8.cpp`
  も同様に
  `new ConvDriver<int8_t, int32_t>()`
  を返す

したがって、
**`convint8` entrypoint の template instantiation そのものは current / packaged-cast-aware family で共通**
と読める。

### 2.2 差は `Tref=int32_t` ではなく output descriptor assembly にある

- current standalone
  `ROCm-repos/MIOpen/driver/conv_driver.hpp`
  では、
  `data_type == miopenInt8 || data_type == miopenInt8x4`
  のとき
  `miopenDataType_t y_type = ... ? miopenInt32 : data_type;`
  を計算し、
  `SetTensorNd(outputTensor, ..., y_type)`
  を呼ぶ
- 同 file の `AddCmdLineArgs()` には
  `in_cast_type` / `out_cast_type` / `wei_cast_type`
  は現れない
- 一方 `miopen-src/driver/conv_driver.hpp` と
  `rocm-libraries/projects/miopen/driver/conv_driver.hpp`
  では、
  output tensor は
  `SetTensorNd(outputTensor, ..., data_type)`
  で作られ、
  その後
  `miopenSetTensorCastType(outputTensor, out_cast_type)`
  が任意で付く
- 同 legacy / packaged-cast-aware family の
  `AddCmdLineArgs()` には
  `in_cast_type` / `out_cast_type` / `wei_cast_type`
  が存在する

したがって、
**`ConvDriver<int8_t, int32_t>` という entrypoint 共有だけでは
direct `y=int32` route の存在を意味しない**。
差はより下流の
descriptor assembly と CLI surface にある。

### 2.3 installed `MIOpenDriver convint8 --help` に direct output-dtype option は見えない

- installed `/opt/rocm/bin/MIOpenDriver convint8 --help`
  の出力には
  `--in_cast_type`, `--out_cast_type`, `--wei_cast_type`
  が出る
- 同 help 出力には
  `--out_data_type` や
  output dtype 自体を切り替える明示的 option は見えない

したがって、
少なくとも observed CLI surface は
**current standalone の explicit `y=int32` descriptor route より、
cast-aware family 側**
に寄っている。

### 2.4 `--out_data_type int32` は unknown option として落ちる

実行:

```bash
/opt/rocm/bin/MIOpenDriver convint8 --out_data_type int32 \
  -n 1 -c 1 -H 1 -W 1 -k 1 -y 1 -x 1 -F 1 -V 0
```

観測:

- `Long Name: out_data_type Not Found !`

したがって、
少なくとも tested installed binary では、
**direct output dtype を明示する obvious CLI option は存在しない**
と読める。

### 2.5 `--out_cast_type int32` も direct `y=int32` route にはならない

実行:

```bash
/opt/rocm/bin/MIOpenDriver convint8 --out_cast_type int32 \
  -n 1 -c 1 -H 1 -W 1 -k 1 -y 1 -x 1 -F 1 -V 0
```

観測:

- `Invalid value for out_cast_type argument:int32`
- `ParseCmdLineArgs() FAILED, rc = 1`

加えて、
既存 follow-up では
`--out_cast_type fp32`
は accept されるが、
problem は
`...INT8-F_coFP32`
となり、
`GEMM not supported with casted tensors on this GPU architecture`
で落ちると確認済みである。

したがって、
installed CLI に visible な cast flag family は
**direct `y=int32` route を表現する syntax ではない**。

---

## 3. Interpretation

- `convint8` の entrypoint が
  `ConvDriver<int8_t, int32_t>`
  で共通なことは、
  verification/reference type の共有までは示すが、
  **runtime output descriptor が `miopenInt32` に組まれることまでは示さない**
- current standalone source は
  INT8 path を
  `output descriptor data type = miopenInt32`
  で表現している
- 一方、
  installed host 上で見えている `convint8` CLI surface は
  `out_cast_type` family を expose しており、
  direct output-dtype knob は visible ではない
- 実際、
  `--out_data_type int32` は unknown option、
  `--out_cast_type int32` は invalid cast token として落ちる
- したがって、
  現時点の最も安全な読みは、
  **tested installed `MIOpenDriver convint8` は、
  current standalone source の direct `y=int32` route を
  obvious な CLI syntax としては expose していない**
  という範囲である
- これは
  「API 一般で direct `y=int32` route が使えない」
  ことを意味しない。
  direct immediate と standard `Find + Forward`
  では同 route が実行成功している
- むしろ、
  current host の閉塞点は
  **installed `convint8` CLI の option surface / descriptor assembly**
  に強く寄る

---

## 4. 少なくともここまでは言える

- `convint8` entrypoint の template instantiation と
  actual output descriptor path は別層である
- current standalone source では
  direct INT8 route は explicit `y=int32` descriptor で表現される
- installed `MIOpenDriver convint8` の visible CLI surface には
  direct `out_data_type` knob は見えない
- `out_cast_type` family は
  direct `y=int32` route の代替ではない
- したがって、
  current host で practical route が閉じて見える主因は、
  少なくとも solver/backend absence ではなく、
  **installed CLI が direct route をそのまま表現しないこと**
  にさらに寄る

---

## 5. 判定

`confirmed`

少なくとも tested installed `/opt/rocm/bin/MIOpenDriver convint8` では、
current standalone source の direct `y=int32` route を
そのまま表す obvious option surface は観測されない。

---

## 6. 根拠リンク

- `../../vega_path_check_logs/vega64_miopendriver_convint8_help_20260320.txt`
- `../../vega_path_check_logs/vega64_miopendriver_out_data_type_int32_20260320.log`
- `../../vega_path_check_logs/vega64_miopendriver_out_cast_type_int32_20260320.log`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/main.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/dm_convint8.cpp`
- `/home/limonene/ROCm-project/WD-Black/miopen-src/driver/conv_driver.hpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-libraries`

---

## 本文書が主張しないこと

- installed `MIOpenDriver convint8` に hidden / undocumented な direct route が絶対に存在しないと断定するものではない
- exact source commit / exact packaging tree を確定したものではない
- AMD の配布物一般について同じことが必ず成り立つと一般化するものではない
- private issue や社内意思決定を推定するものではない
