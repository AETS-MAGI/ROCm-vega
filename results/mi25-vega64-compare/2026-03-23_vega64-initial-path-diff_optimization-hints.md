# Vega64「初期運用一式」差分確定と最適化ヒント

更新日: 2026-03-23 (Asia/Tokyo)
対象: `/home/limonene/ROCm-project/vega_investigations/results/mi25-vega64-compare`

## 1. 目的

「最初の Vega64 側の動かし方（distro ROCm service）が速かったのでは？」という仮説を、
Vega64 単独で **distro系(11435)** と **fork系(21445)** を同条件比較して確定する。

## 2. 比較対象（確定）

- 比較A: `127.0.0.1:11435` (`ollama-rocm.service`)
- 比較B: `127.0.0.1:21445` (`/tmp/ollama-fork-compare/ollama serve`)

共通条件:

- model: `tinyllama:latest`
- prompt: `Write a concise 120-word note about validating legacy GPUs for local LLM inference.`
- `stream=false`
- `num_predict=128`
- `num_thread=16`
- `keep_alive=10m`
- warm-up 1回後に 20 runs

## 3. 「初期運用一式」と fork 運用の差分（事実）

| 観点 | 初期運用（distro ROCm / 11435） | fork運用（21445） |
|---|---|---|
| serve バイナリ | `/usr/bin/ollama` | `/tmp/ollama-fork-compare/ollama` |
| serve バイナリサイズ | 37,427,672 bytes | 78,151,960 bytes |
| serve SHA256 | `ae7fd113...200ec80` | `9cf1fa10...9e83ef7` |
| runnerの `OLLAMA_LIBRARY_PATH` | `/usr/lib/ollama` | `/tmp/ollama-fork-compare/build-gfx900/lib/ollama` |
| runnerで実際にmapされた `libggml-hip.so` | `/usr/lib/ollama/libggml-hip.so` | `/tmp/ollama-fork-compare/build-gfx900/lib/ollama/libggml-hip.so` |
| `libggml-hip.so` サイズ | 1,031,830,744 bytes | 57,794,656 bytes |
| backend | `library=ROCm compute=gfx900` | `library=ROCm compute=gfx900` |
| `NumThreads` | 16 | 16 |

補足:

- 2系統とも runner `/proc/<pid>/maps` 上で `librocblas.so` を `/opt/rocm/lib` から読んでいることを確認。
- つまり「ROCmに乗っていない」問題ではなく、主に **Ollama/ggml 側のバイナリ・ライブラリ系統差** が本体。

## 4. 実測結果（20-run x 4セット）

20-runを4セット採取し、同条件で比較した。

| セットID | distro eval_tps median | fork eval_tps median | median比 (distro/fork) | total_s median 比 (fork/distro) | 補足 |
|---|---:|---:|---:|---:|---|
| `20260323_204838` | 242.805 | 241.422 | 1.0057x | 1.0633x | forkに低速runが3件（`<239 tps`） |
| `20260323_205542` | 242.106 | 242.193 | 0.9996x | 1.0582x | ほぼ同等 |
| `20260323_205615` | 241.800 | 242.092 | 0.9988x | 1.0595x | ほぼ同等 |
| `20260323_205710` | 241.955 | 241.923 | 1.0001x | 1.0571x | ほぼ同等 |

### 4.1 プール結果（80-run）

| Path | n | eval_tps median | eval_tps mean | eval_tps stdev | total_s median |
|---|---:|---:|---:|---:|---:|
| distro11435 | 80 | 242.094 | 242.278 | 0.652 | 0.641294 |
| fork21445 | 80 | 241.923 | 241.377 | 2.633 | 0.680165 |

- `eval_tps` 中央値差: **+0.07%（ほぼ同等）**
- `total_duration` 中央値差: **+6.06%（fork遅い）**

## 5. 何が「初期運用有利」に見えたか

### 5.1 確定できること

- トークン生成そのもの（`eval_tps`）は、再測定ではほぼ同等。
- ただし fork 側は `total_duration` が一貫して長く、分散も大きい。

### 5.2 分解結果（推論）

`total - (load + prompt_eval + eval)` を「その他オーバーヘッド」として見ると:

- distro median: 約 `0.0096s`
- fork median: 約 `0.0444s`
- 差分: 約 `+0.0349s`

[inference / unvalidated]

- fork経路は、生成本体以外（スケジューラ待ち/内部管理/ランナー周辺）のオーバーヘッドが大きい可能性。
- 1セット目の fork にだけ低速run（`<239 tps`）が3件あり、初期印象を「forkが遅い」に寄せた可能性。

## 6. 最適化ヒント（Vega/MI25共通で使える）

1. **比較時は `eval_tps` と `total_duration` を分離して解釈する**
- 生成カーネル性能と、周辺オーバーヘッドを混同しない。

2. **ウォーム後反復は最低2セット（20+20）取る**
- 単一セットでは outlier の影響を受けやすい。

3. **runnerの実ロード先を `/proc/<pid>/maps` で確定する**
- `library=ROCm` 表示だけでは不十分。`libggml-hip.so` の実体パスを確認する。

4. **distro系の安定要素を fork側に移植検討**
- 例: ランナー周辺オーバーヘッドが小さい起動条件・環境変数の再現。
- まずは `PATH`, `OLLAMA_*`, `LD_LIBRARY_PATH` を最小差分で揃えて検証。

5. **MI25側チューニングでも同じ分解指標を採用**
- `eval_tps` が上がらず `total_duration` だけ悪化する改変を早期に弾ける。

## 7. 結論

- 「最初の Vega64 側（distro ROCm）が速かった」感覚は、**方向としては妥当**。
- ただし本質は「生成カーネルが圧倒的に速い」ではなく、
  **distro系の方が全体オーバーヘッドと揺れが小さい**こと。
- 最適化の狙いは、fork側で `eval_tps` を追うだけでなく、
  **`total_duration` の余剰オーバーヘッドを削ること**。

## 8. 参照ログ

- `vega64_distro11435_thread16_keep10m_20run_20260323_204838.jsonl`
- `vega64_fork21445_thread16_keep10m_20run_20260323_204838.jsonl`
- `vega64_distro11435_thread16_keep10m_20run_20260323_205542.jsonl`
- `vega64_fork21445_thread16_keep10m_20run_20260323_205542.jsonl`
- `vega64_distro11435_thread16_keep10m_20run_20260323_205615.jsonl`
- `vega64_fork21445_thread16_keep10m_20run_20260323_205615.jsonl`
- `vega64_distro11435_thread16_keep10m_20run_20260323_205710.jsonl`
- `vega64_fork21445_thread16_keep10m_20run_20260323_205710.jsonl`
- `vega64_forksame_20260323_202017.log`
- `vega64_usrlocal_rocm_21435_20260323_193323.log`
- `2026-03-23_binary-alignment-attempt.md`
