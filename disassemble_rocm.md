# ROCm 逆アセンブル手順（gfx900推論経路向け）

更新日: 2026-03-12
目的: gfx900 環境で INT8 系カーネルが dot4 命令を使っているか、代替積和経路に落ちているかを確認する。

## 1. 方針

- 真実源は生成物（hsaco / 埋め込み code object）と逆アセンブル結果。
- 推論経路の判定本体は vega-rocm.md に記録する。
- 本書は「逆アセンブル実行手順」に限定する。

## 2. 最短コマンド

```bash
# 1) バイナリに含まれる offloading 情報を確認
llvm-objdump --offloading ./your_binary

# 2) hsaco 単体を逆アセンブル
llvm-objdump -d --triple=amdgcn ./your_kernel.hsaco

# 3) 埋め込み code object を含む実行ファイルを逆アセンブル
llvm-objdump -d --triple=amdgcn ./your_binary
```

## 3. gfx900 / dot4 確認フロー（実運用）

### 3.1 対象の特定

- 候補1: 実行時生成 hsaco
- 候補2: ライブラリに埋め込み済み code object
- 候補3: 自前ビルドした HIP バイナリ

```bash
find ~/.cache -type f -name "*.hsaco" 2>/dev/null | head -n 200
find /tmp -type f -name "*.hsaco" 2>/dev/null | head -n 200
```

### 3.2 GFX ターゲット確認

```bash
llvm-objdump --offloading ./target.hsaco
```

`gfx900` が含まれる code object を優先して解析する。

### 3.3 逆アセンブルと命令抽出

```bash
llvm-objdump -d --triple=amdgcn ./target.hsaco > ./target_hsaco.s

# dot4 系命令
rg -n "v_dot4_i32_i8|v_dot4c_i32_i8|sdot4|sudot4" ./target_hsaco.s

# 代替積和の疑い（参考）
rg -n "v_mul|v_mac|v_mad|v_add" ./target_hsaco.s
```

判定の目安:

- dot4 系命令あり: dot4 利用経路の可能性が高い。
- dot4 系命令なし + INT8 実行成功: 代替積和経路の可能性が高い。

## 4. 最小再現（自作カーネルで検証）

dot4 相当の 4 要素積和を明示した最小カーネルを gfx900 向けにビルドし、
命令列を確認する。

```cpp
#include <hip/hip_runtime.h>

__global__ void test_kernel(const int8_t* a, const int8_t* b, int* c)
{
        int i   = threadIdx.x;
        int sum = 0;
        sum += (int)a[i * 4 + 0] * (int)b[i * 4 + 0];
        sum += (int)a[i * 4 + 1] * (int)b[i * 4 + 1];
        sum += (int)a[i * 4 + 2] * (int)b[i * 4 + 2];
        sum += (int)a[i * 4 + 3] * (int)b[i * 4 + 3];
        c[i] = sum;
}
```

```bash
hipcc --offload-arch=gfx900 -O3 test.cpp -o test_gfx900
llvm-objdump --offloading ./test_gfx900
llvm-objdump -d --triple=amdgcn ./test_gfx900 > ./test_gfx900.s
rg -n "dot4|v_mul|v_mac|v_mad|v_add" ./test_gfx900.s
```

## 5. 実験時の注意

- 初回実行は JIT やキャッシュ生成が混ざるため、2回目以降で比較する。
- 比較対象は同一 shape / dtype / layout / バッチで固定する。
- 逆アセンブル結果だけで性能結論を断定せず、ログと併記する。

## 6. vega 調査フローへの接続

既存スクリプトと併用する場合:

```bash
TARGET_HSACO=/path/to/kernel.hsaco \
LLVM_OBJDUMP=llvm-objdump \
./run_vega_path_case.sh int8_case -- \
miopen-driver conv -n 32 -c 64 -H 56 -W 56 -k 64 -y 3 -x 3 -p 1 -q 1 -u 1 -v 1 -F 1 -t 1
```

出力先例:

- `~/vega_path_check_logs/int8_case.hsaco.s`
- `~/vega_path_check_logs/int8_case.dot4_extract.log`
- `~/vega_path_check_logs/int8_case.trace_map.md`

## 7. 参考

- HIP compilers (ROCm):
    https://rocm.docs.amd.com/projects/HIP/en/latest/understand/compilers.html