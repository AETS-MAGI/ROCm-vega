# hsaco_disassembly_notes

更新日: 2026-03-13

## 1. 目的

Vega64(gfx900) 実行ケースで、ukdbから取り出したkernel objectを逆アセンブルし、INT8積和命令の実体を確認する。

## 2. 対象と抽出元

- DB: `~/.cache/miopen/3.5.1.5b515cf1bca-dirty/gfx900_64.ukdb`
- 対象A: `naive_conv.cpp.o` (INT8条件行)
- 対象B: `igemm_v4r1_dynamic.s.o` (`kernel_args=' -Wa,-defsym,ROCM_METADATA_VERSION=5 -mcpu=gfx900'`)

## 3. 実行コマンド

```bash
DB="$(ls -1d ~/.cache/miopen/*/gfx900_64.ukdb | head -n 1)"

# A) naive INT8
sqlite3 "$DB" "SELECT writefile('/tmp/naive_conv_int8.cpp.o.bz2', kernel_blob) FROM kern_db WHERE kernel_name='naive_conv.cpp.o' AND instr(kernel_args,'MIOPEN_USE_INT8=1')>0 LIMIT 1;"
bzip2 -dc /tmp/naive_conv_int8.cpp.o.bz2 > /tmp/naive_conv_int8.cpp.o
/opt/rocm/llvm/bin/llvm-objdump -d --triple=amdgcn /tmp/naive_conv_int8.cpp.o > /tmp/naive_conv_int8.cpp.o.s

# B) igemm_v4r1_dynamic (forced asm case)
sqlite3 "$DB" "SELECT writefile('artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.bz2', kernel_blob) FROM kern_db WHERE kernel_name='igemm_v4r1_dynamic.s.o' AND kernel_args=' -Wa,-defsym,ROCM_METADATA_VERSION=5 -mcpu=gfx900' ORDER BY rowid DESC LIMIT 1;"
bzip2 -dc artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.bz2 > artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o
/opt/rocm/llvm/bin/llvm-objdump -d --triple=amdgcn artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o > artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.s

# 命令探索
rg -n "v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4" /tmp/naive_conv_int8.cpp.o.s artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.s
rg -n "v_mul|v_mad|v_mac|v_add" /tmp/naive_conv_int8.cpp.o.s artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.s | head
```

## 4. 観測結果

- 対象A (`naive_conv.cpp.o`)
  - INT8対象シンボルを確認。
  - `v_dot4_i32_i8` / `v_dot4c_i32_i8` / `sdot4` / `sudot4` は未検出。
  - `v_mul*` / `v_add*` 系命令は検出。

- 対象B (`igemm_v4r1_dynamic.s.o`)
  - 強制ASMケースで実行された `igemm_v4r1_1x1_dynamic_*` に対応するcode objectを抽出。
  - `v_dot4_i32_i8` / `v_dot4c_i32_i8` / `sdot4` / `sudot4` は未検出。
  - `v_mul_lo_u32`, `v_mul_hi_u32`, `v_add_co_u32_e32` などは検出。

## 5. 解釈

- 少なくとも今回抽出できたINT8関連2系統（naive/igemm_v4r1_dynamic）ではdot4系命令は確認できなかった。
- gfx900上でのINT8経路は、dot4非依存の代替積和命令列に依存している可能性が高い。
- ただし、`ConvMlirIgemmFwd` 強制ケースはMLIR lowering段階で失敗しており、同系統kernelの実行命令比較は別ケースで継続が必要。

## 6. 関連証跡

- `vega_path_check_logs/vega64_int8_force_asm_v4r1_1x1.log`
- `vega_path_check_logs/vega64_int8_force_mlir_fwd.log`
- `artifacts/hsaco_extract/igemm_v4r1_dynamic_candidates.txt`
- `artifacts/hsaco_extract/igemm_v4r1_dynamic.s.o.s`