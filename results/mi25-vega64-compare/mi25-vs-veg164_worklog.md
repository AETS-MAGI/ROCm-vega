# MI25 vs Vega64 実験ワークログ（ROCm/Vulkan比較 + ROCm反復）

更新日: 2026-03-23 (Asia/Tokyo)
追記: 2026-03-23 20:17 JST から `fork/fork` 再試行（`build-gfx900/lib/ollama` 相対配置の検証）を開始
対象ディレクトリ: `/home/limonene/ROCm-project/vega_investigations/results/mi25-vega64-compare`

---

## 1. 目的

- MI25（gfx900, ROCm）と Vega64（gfx900, Vulkan/ROCm）の推論速度を、同一モデル・同一プロンプト条件で比較する。
- 差分を「GPU素性差」ではなく「経路・設定差」まで分解して確認する。
- 後続の再現・再検証のため、設定・手順・ログを具体的に固定化する。

---

## 2. ノード構成

| ノード | GPU | 主経路 | 補足 |
|---|---|---|---|
| `hbmx-mi25` | Radeon Instinct MI25 (gfx900, 16GB) | ROCm (`127.0.0.1:11434`) | ローカル forked `ollama-src` バイナリを使用 |
| `abyss-hbmx` | Radeon RX Vega (gfx900, 8GB) | Vulkan (`127.0.0.1:11434`) / ROCm (`127.0.0.1:11435`) | dual service 運用可能 |

参照ラベル方針:

- `[main-node confirmed]` = `hbmx-mi25` で直接確認した事実
- `[abyss-node confirmed]` = `ssh abyss` で直接確認した事実
- `[inference / unvalidated]` = 推論・解釈（追加検証余地あり）

---

## 3. サービス設定（実測）

### 3.1 MI25 側 (`hbmx-mi25`) [main-node confirmed]

`systemctl --user cat ollama` の主要点:

```ini
ExecStart=/home/limonene/ROCm-project/ollama-src/ollama serve
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=10m"
Environment="OLLAMA_LIBRARY_PATH=/home/limonene/ROCm-project/ollama-src/build/lib/ollama"
Environment="LD_LIBRARY_PATH=/home/limonene/ROCm-project/ollama-src/build/lib/ollama"
Environment="ROCBLAS_TENSILE_LIBPATH=/home/limonene/ROCm-project/ROCm-repos_AETS/rocBLAS/build-mi25-gfx900/release/rocblas-install/lib/rocblas/library"
Environment="HIP_VISIBLE_DEVICES=0"
Environment="HSA_OVERRIDE_GFX_VERSION=9.0.0"
```

### 3.2 Vega64 側 (`abyss-hbmx`) [abyss-node confirmed]

Vulkan service (`ollama.service`):

```ini
ExecStart=/home/limonene/.local/bin/ollama-vega-vulkan serve
Environment=OLLAMA_HOST=http://127.0.0.1:11434
```

ROCm service (`ollama-rocm.service`):

```ini
ExecStart=%h/.local/bin/ollama-rocm-serve
Environment=HSA_OVERRIDE_GFX_VERSION=9.0.0
Environment=OLLAMA_LLM_LIBRARY=rocm
Environment=OLLAMA_HOST=127.0.0.1:11435
```

`~/.local/bin/ollama-rocm-serve` の要点:

```bash
ROCM_OLLAMA_BIN="/usr/bin/ollama"
export OLLAMA_LLM_LIBRARY=rocm
export OLLAMA_HOST=127.0.0.1:11435
exec "$ROCM_OLLAMA_BIN" serve
```

つまり Vega64 側は:

- Vulkan: `/usr/local/bin/ollama` + `ollama-vega-vulkan` wrapper
- ROCm: `/usr/bin/ollama` + `ollama-rocm-serve` wrapper

で、バイナリ・ラッパーが別スタック。

---

## 4. 実験条件（共通）

### 4.1 リクエスト条件

- Model: `tinyllama:latest`
- Prompt: `Write a concise 120-word note about validating legacy GPUs for local LLM inference.`
- `stream=false`
- `keep_alive=0s`
- `options.num_predict=128`
- `options.temperature=0.1`

### 4.2 主要メトリクス

- `total_duration_ns`
- `eval_duration_ns`
- `eval_count`
- `eval_tps = eval_count * 1e9 / eval_duration_ns`
- `rocm-smi` から `GPU use (%)`（取得できる場合）

---

## 5. 手順

### 5.1 Step A: シングルラン比較（初期切り分け）

1. MI25 ROCm (`127.0.0.1:11434`) を 1 回実行。
2. Vega64 Vulkan (`abyss:11434`) を 1 回実行。
3. Vega64 ROCm (`abyss:11435`) を 1 回実行。
4. JSON と rocm-smi ログを保存。

成果物:

- `mi25_tiny_bench_20260323_182115.json`
- `vega64_tiny_bench_20260323_182144.json` (Vulkan)
- `vega64_rocm_tiny_bench_20260323_183056.json` (ROCm)
- 各 `.smi.log`

### 5.2 Step B: Vega64 を ROCm 寄せして反復

ユーザー方針: 「Vega64 を ROCm に寄せてから反復」

実施:

```bash
ssh abyss 'systemctl --user stop ollama'
ssh abyss 'systemctl --user is-active ollama'        # inactive
ssh abyss 'systemctl --user is-active ollama-rocm'   # active
ssh abyss 'ss -ltnp | rg "11434|11435|ollama"'
```

結果:

- `11434` (Vulkan) 停止
- `11435` (ROCm) のみ listen

### 5.3 Step C: ROCm vs ROCm 反復（5 runs × 2ノード）

- MI25: `127.0.0.1:11434`
- Vega64: `abyss 127.0.0.1:11435`
- 同一 payload を Python (`urllib.request`) で POST
- 各 run を JSONL に 1 行ずつ記録

有効データ（正本）:

- `mi25_rocm_repeat_20260323_184113.jsonl`
- `vega64_rocm_repeat_20260323_184113.jsonl`

注意: `*_183958.jsonl` は quoting 事故の混入があるため参考扱い。

---

## 6. 結果

### 6.1 シングルラン結果

| Host | Path | total(s) | eval(s) | eval_count | eval_tps |
|---|---|---:|---:|---:|---:|
| MI25 (`hbmx-mi25`) | ROCm | 2.4187 | 0.6089 | 128 | 210.20 |
| Vega64 (`abyss`) | Vulkan | 2.2791 | 0.5726 | 128 | 223.54 |
| Vega64 (`abyss`) | ROCm | 1.5609 | 0.5481 | 128 | 233.55 |

### 6.2 反復結果（ROCm vs ROCm, 5 runs）

#### MI25 ROCm (`mi25_rocm_repeat_20260323_184113.jsonl`)

| run | total_duration_ns | eval_duration_ns | eval_tps |
|---:|---:|---:|---:|
| 1 | 1760663169 | 606812373 | 210.938 |
| 2 | 1743011289 | 619192477 | 206.721 |
| 3 | 1828062663 | 692187439 | 184.921 |
| 4 | 2020192067 | 634089150 | 201.864 |
| 5 | 1833103957 | 687939478 | 186.063 |

#### Vega64 ROCm (`vega64_rocm_repeat_20260323_184113.jsonl`)

| run | total_duration_ns | eval_duration_ns | eval_tps |
|---:|---:|---:|---:|
| 1 | 1525017461 | 502092758 | 254.933 |
| 2 | 1491803974 | 500884404 | 255.548 |
| 3 | 1486346874 | 496520810 | 257.794 |
| 4 | 1530341291 | 540700518 | 236.730 |
| 5 | 1439889686 | 495482832 | 258.334 |

### 6.3 集計（`2026-03-23_rocm-repeat-summary.md`）

| Host | eval_tps min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 184.92 | 210.94 | 198.10 | 201.86 | 10.69 |
| Vega64/ROCm | 236.73 | 258.33 | 252.67 | 255.55 | 8.07 |

中央値比:

- `Vega64/ROCm ÷ MI25/ROCm = 1.266x`

---

## 7. 差分解釈（ここ重要）

### 7.1 観測事実 [confirmed]

- 両側とも `library=ROCm` 経路で動作。
- 両側とも `GPULayers:23` の load request を確認。
- ただし `NumThreads` が不一致:
  - MI25: `NumThreads:4` [main-node confirmed]
  - Vega64 ROCm: `NumThreads:16` [abyss-node confirmed]

### 7.2 解釈 [inference / unvalidated]

- `1.266x` を「素のGPU実力差」と断定するのは早い。
- 現時点では「MI25 側の経路未活性」より、
  「MI25 側スタック/設定が不利（特に thread 設定差）」の寄与が強い可能性。
- さらに、ローカル forked バイナリ（MI25）と distro ROCm wrapper（Vega64）で実行スタックが異なるため、純粋比較はまだ不十分。

---

## 8. 再現コマンド（最小）

### 8.1 abyss を ROCm-only に寄せる

```bash
ssh abyss 'systemctl --user stop ollama'
ssh abyss 'systemctl --user is-active ollama'
ssh abyss 'systemctl --user is-active ollama-rocm'
ssh abyss 'ss -ltnp | rg "11434|11435|ollama"'
```

### 8.2 単発生成テスト（ROCm側）

```bash
# MI25
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"tinyllama:latest","prompt":"short rocm check","stream":false}'

# Vega64 (ROCm)
ssh abyss "python3 - <<'PY'
import json, urllib.request
payload = {
  'model': 'tinyllama:latest',
  'prompt': 'short rocm check',
  'stream': False,
}
req = urllib.request.Request(
  'http://127.0.0.1:11435/api/generate',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type': 'application/json'},
)
with urllib.request.urlopen(req, timeout=120) as r:
  print(r.read().decode('utf-8'))
PY"
```

### 8.3 差分確認ログ

```bash
# MI25
journalctl --user -u ollama --since '2026-03-23 18:41:00' --until '2026-03-23 18:42:00' --no-pager \
  | rg 'load request|NumThreads|GPULayers|library=ROCm|compute=gfx900'

# Vega64 ROCm
ssh abyss "journalctl --user -u ollama-rocm --since '2026-03-23 18:41:00' --until '2026-03-23 18:42:00' --no-pager \
  | rg 'load request|NumThreads|GPULayers|library=ROCm|compute=gfx900'"
```

### 8.4 反復ベンチ（5 runs）最小サンプル

```bash
# ローカル(MI25) 5回
for i in $(seq 1 5); do
  python3 - <<'PY'
import json, urllib.request
payload = {
  'model':'tinyllama:latest',
  'prompt':'Write a concise 120-word note about validating legacy GPUs for local LLM inference.',
  'stream':False,
  'keep_alive':'0s',
  'options':{'num_predict':128,'temperature':0.1},
}
req = urllib.request.Request(
  'http://127.0.0.1:11434/api/generate',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type':'application/json'},
)
with urllib.request.urlopen(req, timeout=120) as r:
  print(r.read().decode('utf-8'))
PY
done

# remote(abyss Vega64/ROCm) 5回
for i in $(seq 1 5); do
  ssh abyss "python3 - <<'PY'
import json, urllib.request
payload = {
  'model':'tinyllama:latest',
  'prompt':'Write a concise 120-word note about validating legacy GPUs for local LLM inference.',
  'stream':False,
  'keep_alive':'0s',
  'options':{'num_predict':128,'temperature':0.1},
}
req = urllib.request.Request(
  'http://127.0.0.1:11435/api/generate',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type':'application/json'},
)
with urllib.request.urlopen(req, timeout=120) as r:
  print(r.read().decode('utf-8'))
PY"
done
```

### 8.5 JSONL 収集と集計（実運用コマンド）

```bash
cd /home/limonene/ROCm-project/vega_investigations/results/mi25-vega64-compare
TS=$(date +%Y%m%d_%H%M%S)
MI25_OUT="mi25_rocm_repeat_${TS}.jsonl"
VEGA_OUT="vega64_rocm_repeat_${TS}.jsonl"

# MI25 local -> JSONL
for i in $(seq 1 5); do
  python3 - <<'PY' >> "$MI25_OUT"
import json, urllib.request
payload = {
  'model':'tinyllama:latest',
  'prompt':'Write a concise 120-word note about validating legacy GPUs for local LLM inference.',
  'stream':False,
  'keep_alive':'0s',
  'options':{'num_predict':128,'temperature':0.1},
}
req = urllib.request.Request(
  'http://127.0.0.1:11434/api/generate',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type':'application/json'},
)
with urllib.request.urlopen(req, timeout=120) as r:
  print(r.read().decode('utf-8'))
PY
done

# Vega64 remote(ROCm) -> JSONL
for i in $(seq 1 5); do
  ssh abyss "python3 - <<'PY'
import json, urllib.request
payload = {
  'model':'tinyllama:latest',
  'prompt':'Write a concise 120-word note about validating legacy GPUs for local LLM inference.',
  'stream':False,
  'keep_alive':'0s',
  'options':{'num_predict':128,'temperature':0.1},
}
req = urllib.request.Request(
  'http://127.0.0.1:11435/api/generate',
  data=json.dumps(payload).encode('utf-8'),
  headers={'Content-Type':'application/json'},
)
with urllib.request.urlopen(req, timeout=120) as r:
  print(r.read().decode('utf-8'))
PY" >> "$VEGA_OUT"
done

# eval_tps 集計（簡易）
python3 - <<'PY'
import json, pathlib, statistics as st
for name in sorted(pathlib.Path('.').glob('*_rocm_repeat_*.jsonl')):
    rows = [json.loads(x) for x in name.read_text().splitlines() if x.strip().startswith('{')]
    tps = [r['eval_count'] * 1e9 / r['eval_duration'] for r in rows if r.get('eval_duration')]
    if not tps:
        continue
    print(
        name.name,
        "n=", len(tps),
        "min=", f"{min(tps):.2f}",
        "max=", f"{max(tps):.2f}",
        "mean=", f"{st.mean(tps):.2f}",
        "median=", f"{st.median(tps):.2f}",
    )
PY
```

---

## 9. 追加検証（2026-03-23 19:27 JST）

実施内容:

- `NumThreads=16` を MI25 側にも明示指定して Vega64 側に合わせた。
- `keep_alive=10m` を API 側でも明示し、各ノード 1 回 warm-up 後に 5 run を計測。

生成ファイル:

- `mi25_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `vega64_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `mi25_threads16_keepalive10m_20260323_192700.journal.log`
- `vega64_threads16_keepalive10m_20260323_192700.journal.log`
- `2026-03-23_threads16_keepalive10m_summary.md`

集計（`2026-03-23_threads16_keepalive10m_summary.md`）:

| Host | eval_tps min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 199.99 | 222.48 | 216.11 | 221.55 | 8.51 |
| Vega64/ROCm | 243.19 | 243.79 | 243.42 | 243.37 | 0.20 |

中央値比:

- `Vega64/ROCm ÷ MI25/ROCm = 1.098x`

補足（journal 事実）:

- MI25 load request: `NumThreads:16`, `GPULayers:23`, `library=ROCm`
- Vega64 load request: `NumThreads:16`, `GPULayers:23`, `library=ROCm`

解釈:

- 先行結果の `1.266x` から `1.098x` まで差が縮小した。
- 少なくとも今回の条件では、差分のかなりの部分が「MI25 経路未活性」より「設定差（NumThreads など）」で説明できる。
- ただし依然としてバイナリ/サービス系統差（local fork vs distro wrapper）は残るため、純粋なハード比較としては未完。

---

## 10. バイナリ系統そろえの試行（2026-03-23 19:33-19:39 JST）

目的:

- `local fork vs distro` のコンファウンダを減らすため、MI25/Vega64 のバイナリ系統を揃えて再計測できるか確認。

結果（要約）:

1. 両側 `/usr/local/bin/ollama` 試行:
   - ROCm ではなく **CPU backend** に落ちたため比較無効。
2. MI25 fork binary を abyss に持ち込み（`fork/fork`）試行:
   - abyss 側で **CPU backend** のまま（`library=cpu`）。
3. abyss の `/usr/bin/ollama` を MI25 へ持ち込み（`distro/distro`）試行:
   - MI25 側で `GLIBC_2.43` 不足により実行不可。

この時点の結論（暫定）:

- 19:39 時点では即日でのバイナリ系統そろえ比較は難しい、という判断だった。
- ただしこの後の再試行（Section 11）で `fork/fork` 条件の ROCm 起動に成功した。

詳細ログ:

- `2026-03-23_binary-alignment-attempt.md`

---

## 11. 継続検証（2026-03-23 20:17-20:20 JST, `fork/fork` で再試行）

狙い:

- 同系統バイナリ比較を再チャレンジし、`local fork vs distro` の差を縮める。

実施:

1. MI25 側は既存 fork サービスを使用（`/home/limonene/ROCm-project/ollama-src/ollama`）。
2. Vega64 側は MI25 の fork バイナリを `/tmp/ollama-fork-compare/ollama` にコピー。
3. `build-gfx900/lib/ollama` を **バイナリ相対パス**で配置。
4. `OLLAMA_LIBRARY_PATH=/tmp/ollama-fork-compare/build-gfx900/lib/ollama` を指定して起動（port `21445`）。
5. SSH tunnel `22445 -> abyss:21445` でローカルから同一 harness で計測。
6. `num_thread=16`, `keep_alive=10m`, warm-up 1 回除外, 5 runs + 5 runs。

確認できた事実:

- Vega64 側ログで `library=ROCm compute=gfx900` を確認。
- `load_backend: loaded ROCm backend from /tmp/ollama-fork-compare/build-gfx900/lib/ollama/libggml-hip.so` を確認。
- `NumThreads:16`, `GPULayers:23` を両側で確認。

集計（`2026-03-23_forksame-summary.md`）:

| Host | eval_tps min | max | mean | median | stdev |
|---|---:|---:|---:|---:|---:|
| MI25/ROCm | 208.45 | 224.33 | 216.98 | 219.45 | 6.51 |
| Vega64/ROCm | 214.66 | 248.77 | 241.58 | 248.50 | 13.47 |

中央値比:

- `Vega64/ROCm ÷ MI25/ROCm = 1.132x`

解釈:

- `NumThreads` 差の除去で `1.266x -> 1.098x` に縮小した後、
- `fork/fork` 条件に寄せた再試行では `1.132x`。
- したがって残差は設定だけでなく、ライブラリセット・ホスト差・実行スタック差が混在している可能性が高い。

追加反復（同条件 20 runs + 20 runs, `2026-03-23_forksame-20run-summary.md`）:

| Host | eval_tps min | p10 | median | p90 | max | mean | stdev |
|---|---:|---:|---:|---:|---:|---:|---:|
| MI25/ROCm | 220.41 | 221.40 | 222.63 | 223.46 | 223.70 | 222.48 | 0.84 |
| Vega64/ROCm | 232.17 | 244.34 | 247.43 | 248.65 | 249.05 | 246.12 | 4.67 |

20 runs 中央値比:

- `Vega64/ROCm ÷ MI25/ROCm = 1.111x`

補足:

- 5-run の `1.132x` より 20-run では `1.111x` に収束。
- 差は依然残るが、振れ幅をならすと 1.1x 前後に落ち着く傾向。

---

## 12. 関連ファイル

- `2026-03-23_tinyllama_quick-compare.md`
- `2026-03-23_rocm-repeat-summary.md`
- `2026-03-23_threads16_keepalive10m_summary.md`
- `2026-03-23_binary-alignment-attempt.md`
- `2026-03-23_forksame-summary.md`
- `2026-03-23_forksame-20run-summary.md`
- `2026-03-23_forksame-thread4-20run-summary.md`
- `2026-03-23_forksame-coldstart-summary.md`
- `2026-03-23_forksame-smi-verified-5run-summary.md`
- `2026-03-23_vega64-initial-path-diff_optimization-hints.md`
- `mi25_rocm_repeat_20260323_184113.jsonl`
- `vega64_rocm_repeat_20260323_184113.jsonl`
- `mi25_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `vega64_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `mi25_rocm_forksame_repeat_20260323_202017.jsonl`
- `vega64_rocm_forksame_repeat_20260323_202017.jsonl`
- `mi25_rocm_forksame20_repeat_20260323_202220.jsonl`
- `vega64_rocm_forksame20_repeat_20260323_202220.jsonl`
- `mi25_rocm_forksame_thread4_20run_20260323_203048.jsonl`
- `vega64_rocm_forksame_thread4_20run_20260323_203048.jsonl`
- `mi25_rocm_forksame_coldstart_10run_20260323_203158.jsonl`
- `vega64_rocm_forksame_coldstart_10run_20260323_203158.jsonl`
- `mi25_rocm_forksame_smi_verified_5run_20260323_203402.jsonl`
- `vega64_rocm_forksame_smi_verified_5run_20260323_203402.jsonl`
- `mi25_forksame_20260323_202017.journal.log`
- `vega64_forksame_20260323_202017.log`
- `mi25_usrlocal_rocm_21434_20260323_193323.log`
- `vega64_usrlocal_rocm_21435_20260323_193323.log`
- `vega64_forkcopy_rocm_21437_20260323.log`
- `mi25_forksame_thread4_20run_20260323_203048.smi.log`
- `vega64_forksame_thread4_20run_20260323_203048.smi.log`
- `mi25_forksame_coldstart_10run_20260323_203158.smi.log`
- `vega64_forksame_coldstart_10run_20260323_203158.smi.log`
- `mi25_forksame_smi_verified_5run_20260323_203402.smi.log`
- `vega64_forksame_smi_verified_5run_20260323_203402.smi.log`

---

## 13. 現状マトリックス（2026-03-23 時点）

### 13.1 実行経路マトリックス

| ノード/比較軸 | サービス/バイナリ系統 | ポート | backend表示 | GPU比較に使えるか | 判定 |
|---|---|---:|---|---|---|
| MI25 (`hbmx-mi25`) | 既存 fork ROCm (`ollama-src/ollama`) | `11434` | `library=ROCm` | はい | `OK` |
| Vega64 (`abyss-hbmx`) | `ollama.service` (Vulkan系) | `11434` | `library=Vulkan` | 限定的 | `限定` |
| Vega64 (`abyss-hbmx`) | `ollama-rocm.service` (`/usr/bin/ollama`) | `11435` | `library=ROCm` | はい | `OK` |
| 両側 `/usr/local/bin/ollama` 試行 | usr-local 系そろえ | `21434/21435` | `library=cpu` | いいえ | `NG` |
| MI25 fork binary を abyss へ持込（初回） | `/tmp/ollama-fork-gfx900-test` | `21437` | `library=cpu` | いいえ | `NG` |
| abyss `/usr/bin/ollama` を MI25 へ持込 | distro->MI25 | - | 起動不可 (`GLIBC_2.43`) | いいえ | `NG` |
| `fork/fork` 再試行（相対 `build-gfx900` 配置） | MI25既存fork + abyssコピーfork | `11434/21445` | 両側 `library=ROCm` | はい | `OK` |

### 13.2 速度比較マトリックス

| 比較 | 条件のそろい具合 | 中央値比 (Vega64/MI25) | 判定 |
|---|---|---:|---|
| MI25/ROCm vs Vega64/Vulkan（単発） | 低 | 約 `1.06x` | 参考値 |
| MI25/ROCm vs Vega64/ROCm（単発） | 中 | 約 `1.11x` | 参考値 |
| ROCm vs ROCm 5-run（初期） | 中（`NumThreads` 不一致） | `1.266x` | コンファウンダ大 |
| `num_thread=16` + `keep_alive=10m` 5-run | 高 | `1.098x` | 現実運用に近い |
| `fork/fork`（同系統）5-run | 高 | `1.132x` | 系統そろえ成功 |
| `fork/fork`（同系統）20-run | 高（分散評価あり） | `1.111x` | 現在の代表値候補 |
| `fork/fork` + `num_thread=4` 20-run | 高（thread感度試験） | `1.132x` | 低threadで差が拡大 |
| `fork/fork` + `keep_alive=0s` 10-run | 中（cold-start寄り） | `1.197x` | load影響込みで差が拡大 |
| `fork/fork` + smi有効採取 5-run | 高（監視再確認） | `1.097x` | warm比較では約1.1xを再確認 |

### 13.3 現時点の一言結論

| 観点 | 判定 |
|---|---|
| ROCm 同士で比較できるか | `はい` |
| 完全同一スタック比較か | `まだ未完`（host差・周辺環境差は残る） |
| 現時点での実用的な速度差 | Vega64 が **約 1.1x** 優位 |
| cold-start を含む体感差 | Vega64 が **約 1.2x** まで広がる傾向 |

### 13.4 観測補足（`rocm-smi`）

- MI25 側は `/usr/bin/rocm-smi` で継続取得可能。
- Vega64 側は `ssh` 非ログイン実行時に `rocm-smi` が PATH に無いため、
  `rocm-smi: command not found` が出るケースがあった。
- Vega64 側は `/opt/rocm/bin/rocm-smi` を絶対指定することで再採取できることを確認済み。

---

## 14. Vega64「初期運用一式 vs fork運用」差分確定（2026-03-23 20:57 JST）

背景:

- 「最初の Vega64 側（distro ROCm service）のほうが速かったのでは？」という仮説を検証。
- Vega64 単独で `11435(distro)` と `21445(fork)` を同条件再測定した。

条件:

- `tinyllama:latest`, `num_thread=16`, `keep_alive=10m`, warm-up後 20-run
- 合計 4セット（`20260323_204838`, `205542`, `205615`, `205710`）

### 14.1 実測サマリ

| セット | distro (11435) eval_tps median | fork (21445) eval_tps median | median比 (distro/fork) | total_s median 比 (fork/distro) |
|---|---:|---:|---:|---:|
| set-1 (`20260323_204838`) | 242.805 | 241.422 | 1.0057x | 1.0633x |
| set-2 (`20260323_205542`) | 242.106 | 242.193 | 0.9996x | 1.0582x |
| set-3 (`20260323_205615`) | 241.800 | 242.092 | 0.9988x | 1.0595x |
| set-4 (`20260323_205710`) | 241.955 | 241.923 | 1.0001x | 1.0571x |
| pooled 80-run | 242.094 | 241.923 | 1.0007x | 1.0606x |

### 14.2 事実として確定した差分

| 項目 | distro ROCm (11435) | fork ROCm (21445) |
|---|---|---|
| serve binary | `/usr/bin/ollama` | `/tmp/ollama-fork-compare/ollama` |
| runner library path | `/usr/lib/ollama` | `/tmp/ollama-fork-compare/build-gfx900/lib/ollama` |
| mapped `libggml-hip.so` | `/usr/lib/ollama/libggml-hip.so` | `/tmp/ollama-fork-compare/build-gfx900/lib/ollama/libggml-hip.so` |
| backend | 両方 `library=ROCm compute=gfx900` | 両方 `library=ROCm compute=gfx900` |

### 14.3 解釈

- `eval_tps`（生成本体）はほぼ同等。
- ただし `total_duration` は fork 側が一貫して長く、揺れも大きい。
- したがって「初期運用が有利」に見えた主因は、
  「生成カーネルの圧倒差」より **周辺オーバーヘッド/安定性差** の可能性が高い。

詳細レポート:

- `2026-03-23_vega64-initial-path-diff_optimization-hints.md`

---

## 15. 公開用サマリ反映（vega-hbmx-pages）

このワークログの要点を、公開閲覧向けページへ反映した。

- 追加ページ:
  - `vega-hbmx-pages/case-study/mi25-vega64-comparison-case-study.html`
- 導線更新:
  - `vega-hbmx-pages/case-study/case-study-index.html`
  - `vega-hbmx-pages/index.html`
- 可視化更新:
  - 比率推移チャート（Vega64/MI25）
  - Vega64内経路差分チャート（distro vs fork, pooled 80-run）

公開ページ側で扱う主軸:

- 主比較の推移（`1.266x -> 1.098x -> 1.111x`）
- Vega64内経路差分（distro vs fork, pooled 80-run）
- `eval_tps` と `total_duration` の分離解釈
