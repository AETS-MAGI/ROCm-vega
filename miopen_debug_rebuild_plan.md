# MIOpen Debug Rebuild Plan

作成日: 2026-03-13

## 目的

`/opt/rocm` 既存環境を壊さずに、ローカルDebug版MIOpenで同一ケースを再現し、
`miirCreateHandle` 由来の失敗分岐を runtime 側で確定する。

## 前提

- ROCm 実行環境は既存の `/opt/rocm` を使用
- MIOpen ソースツリーを手元に持っている
- rocMLIR ソースツリーを手元に持っている
- この調査ディレクトリで `run_vega_path_case.sh` が実行できる

## 0. rocMLIR をローカルに install

`/opt/rocm` に `rocMLIRConfig.cmake` が無い環境では先にこの手順を実施する。

```bash
cd /home/limonene/ROCm-project/tank/lab_notebook/notes/vega_investigations

ROCMLIR_PREFIX=$HOME/local/rocmlir \
bash ./tools/build_rocmlir_local.sh \
  /path/to/rocMLIR
```

期待する生成物:
- `$ROCMLIR_PREFIX/lib/cmake/rocMLIR/rocMLIRConfig.cmake`

## 1. ローカルDebug版をビルド

```bash
cd /home/limonene/ROCm-project/tank/lab_notebook/notes/vega_investigations

MIOPEN_PREFIX=$HOME/local/miopen-debug \
ROCMLIR_PREFIX=$HOME/local/rocmlir \
bash ./tools/build_miopen_debug_local.sh \
  /path/to/rocm-libraries/projects/miopen
```

メモ:
- デフォルトは `Debug` ビルド
- `BUILD_DEV=On` で DB/キャッシュの切り分けがしやすい
- MLIR連携は `-DMIOPEN_USE_MLIR=On` のまま
- `ROCMLIR_PREFIX` を渡すと自動で `rocMLIR_DIR=$ROCMLIR_PREFIX/lib/cmake/rocMLIR` を探索

## 2. ローカルMIOpenでケース再現

```bash
cd /home/limonene/ROCm-project/tank/lab_notebook/notes/vega_investigations

bash ./tools/run_case_with_local_miopen.sh \
  $HOME/local/miopen-debug \
  vega64_int8_force_mlir_fwd_local_dbg -- \
  MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1
```

## 3. 次の最小計測パッチ方針

ローカルソースの `src/mlir_build.cpp` に一時ログを入れる。

観測したい点:
- `AutoMiirHandle` で `handle == nullptr` か
- `miirLowerTuningParams` の戻り値
- `MiirIsConfigApplicable` / `MiirGetKernelCount` / `MiirGetWorkspaceSize` の値

期待される判定:
- `handle == nullptr` なら `miirCreateHandle` 側（`parseConvConfig` など）失敗が最有力
- `handle != nullptr` で `miirLowerTuningParams == MIIR_INVALID_PARAM` なら lowering パスの失敗

## 4. ログ採取の確認ポイント

- 実行ログ先: `~/vega_path_check_logs/<case_id>.log`
- `LD_LIBRARY_PATH` の先頭にローカル `lib` が来ていること
- `MIOpen(HIP):` ログの solver 経路が従来再現と一致すること

## 5. ロールバック

ロールバックは不要。`LD_LIBRARY_PATH` を戻せば標準の `/opt/rocm` に復帰する。
