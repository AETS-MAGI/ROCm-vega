# MI25 vs Vega64 実験ワークログ（ROCm/Vulkan比較 + ROCm反復）

更新日: 2026-03-23 (Asia/Tokyo)
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

## 10. 関連ファイル

- `2026-03-23_tinyllama_quick-compare.md`
- `2026-03-23_rocm-repeat-summary.md`
- `2026-03-23_threads16_keepalive10m_summary.md`
- `mi25_rocm_repeat_20260323_184113.jsonl`
- `vega64_rocm_repeat_20260323_184113.jsonl`
- `mi25_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
- `vega64_rocm_threads16_keepalive10m_repeat_20260323_192700.jsonl`
