# miir_runtime_trace

作成日: 2026-03-13

## 目的

`/opt/rocm` 実ランタイムで `miirCreateHandle` 系の戻り値を採取し、
`MIIR_INVALID_PARAM` の分岐点を特定する。

## 追加した実行物

- `run_vega_path_case_miir_trace.sh`
- `tools/miir_preload_trace.c`

## 実行コマンド

```bash
cd /home/limonene/ROCm-project/vega-hbmx-investigations/vega_investigations
bash ./run_vega_path_case_miir_trace.sh vega64_int8_force_mlir_fwd_trace -- \
  MIOpenDriver convint8 -n 32 -c 64 -H 56 -W 56 -k 64 -y 1 -x 1 -p 0 -q 0 -u 1 -v 1 \
  -S ConvMlirIgemmFwd -F 1 -t 1
```

## 観測

- ケース本体は従来どおり `miirLowerTuningParams MIIR_INVALID_PARAM` で失敗。
- しかし `vega64_int8_force_mlir_fwd_trace.log` に `[MIIR_TRACE]` 行が出ない。

## 補助確認

```bash
nm -D /opt/rocm/lib/libMIOpen.so.1.0 | rg 'MiirGenLaunchParams|MiirIsConfigApplicable|MiirGetKernelCount|MiirGetWorkspaceSize'
```

- `miopen::Miir*` ラッパは `GLOBAL DEFAULT` で存在。

```bash
nm -D /opt/rocm/lib/libMIOpen.so.1.0 | rg 'miirCreateHandle|miirLowerTuningParams|miirLowerBin'
```

- `miir*` C API シンボルは見えない。

## 解釈

- 現行の LD_PRELOAD フック方式では、実際に使われている MIIR 呼び出しを捕捉できていない。
- 最終分岐確定には、`/opt/rocm` 実体への直接計測（デバッグ再ビルド等）が必要。
