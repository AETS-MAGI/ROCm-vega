# 2026-03-18 rocBLAS INT8 backend probe on Vega64

## 1. 目的

`GemmFwd1x1_0_1_int8` の MIOpen-side runtime follow-up とは切り分けて、
gfx900 (Vega64) で rocBLAS の INT8 GEMM backend 自体が成立するかを確認する。

このノートの役割は、
`MIOpen conv route が通らない` ことと
`gfx900 で INT8 GEMM backend 自体が動かない` ことを分離することである。

---

## 2. 環境

- GPU: Vega64 (`gfx900`)
- ROCm: `7.2.26043`
- rocBLAS client: `5.2.0`
- executable: `/opt/rocm/bin/rocblas-bench`

---

## 3. 実行コマンド

### 3.1 小さな sanity case

```bash
/opt/rocm/bin/rocblas-bench \
  -f gemm_ex --transposeA N --transposeB N \
  -m 128 -n 128 -k 128 \
  --a_type i8_r --b_type i8_r --c_type i32_r --d_type i32_r --compute_type i32_r \
  --lda 128 --ldb 128 --ldc 128 --ldd 128 \
  --alpha 1 --beta 0 --initialization rand_int \
  -i 1 -j 1 -v 1 -t 1
```

### 3.2 conv-like shape

```bash
/opt/rocm/bin/rocblas-bench \
  -f gemm_ex --transposeA N --transposeB N \
  -m 64 -n 100352 -k 64 \
  --a_type i8_r --b_type i8_r --c_type i32_r --d_type i32_r --compute_type i32_r \
  --lda 64 --ldb 64 --ldc 64 --ldd 64 \
  --alpha 1 --beta 0 --initialization rand_int \
  -i 1 -j 1 -v 1 -t 1
```

---

## 4. 観測結果

### 4.1 sanity case

Fact:

- device は `AMD Radeon RX Vega gfx900:xnack-` と認識された
- `128x128x128` case は成功
- `norm_error_1 = 0`

Observed summary:

```text
N,N,128,128,128,...,rocblas-Gflops=51.3806,...,norm_error_1=0
```

### 4.2 conv-like shape

Fact:

- `64x100352x64` case も成功
- `norm_error_1 = 0`

Observed summary:

```text
N,N,64,100352,64,...,rocblas-Gflops=1568.38,...,norm_error_1=0
```

Interpretation:

- 少なくとも standalone rocBLAS GEMM backend としては、
  gfx900 で `i8_r -> i32_r` の GEMM は成立する。
- しかも conv-like shape でも即座に failure になるわけではない。

---

## 5. 根拠リンク（ログ / コード / artifact）

### ログ

- `../../vega_path_check_logs/vega64_rocblas_int8_gemm_128_128_128_20260318.log`
- `../../vega_path_check_logs/vega64_rocblas_int8_gemm_64_100352_64_20260318.log`

### コード

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/src/gemm_v2.cpp`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocBLAS/library/src/tensile_host.cpp`

### installed artifact

- `/opt/rocm/lib/rocblas/library/TensileLibrary_lazy_gfx900.dat`
- `/opt/rocm/lib/rocblas/library/TensileLibrary_Type_I8I_HPA_Contraction_l_Ailk_Bjlk_Cijk_Dijk_fallback_gfx900.hsaco`
- `/opt/rocm/lib/rocblas/library/TensileLibrary_Type_I8I_HPA_Contraction_l_Ailk_Bljk_Cijk_Dijk_fallback_gfx900.hsaco`
- `/opt/rocm/lib/rocblas/library/TensileLibrary_Type_I8I_HPA_Contraction_l_Alik_Bjlk_Cijk_Dijk_fallback_gfx900.hsaco`
- `/opt/rocm/lib/rocblas/library/TensileLibrary_Type_I8I_HPA_Contraction_l_Alik_Bljk_Cijk_Dijk_fallback_gfx900.hsaco`

---

## 6. 判定

`confirmed`

少なくとも standalone rocBLAS backend としては、
gfx900 (Vega64) 上で INT8 GEMM 実行は成立する。

この confirmed は、

- MIOpen convolution path が rocBLAS backend まで到達すること
- `GemmFwd1x1_0_1_int8` の `Not applicable` 主因

を確認したものではない。

---

## 7. 次アクション

1. `GemmFwd1x1_0_1_int8` の conv route がどの条件なら `CallGemm` へ到達するかを切り分ける
2. 必要なら `MIOPEN_GEMM_ENFORCE_BACKEND` を使って backend 選択境界を追加確認する
3. MIOpen 側の Find / GetWorkspaceSizes / GetSolution と backend standalone success の間にある条件差を整理する
