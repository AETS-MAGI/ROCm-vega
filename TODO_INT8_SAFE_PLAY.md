# TODO_INT8_SAFE_PLAY.md
## Vegaちゃん向け INT8 安全あそび TODO

### 目的
Vega/gfx900 で INT8 を「無理やり速い solver に乗せる」のではなく、  
**安全に動く shape / solver / 条件** を先に見つける。

---

## 0. 前提整理
- [ ] INT8 は自然選択だと `ConvDirectNaiveConvFwd` が中心
- [ ] 強制 MLIR は `MIIR_INVALID_PARAM`
- [ ] 強制 DLOPS は `not applicable`
- [ ] 強制 ASM v4r1 dynamic は memory access fault
- [ ] Xdlops 系は INT8/FP16/BFP16 で系統的に失敗寄り
- [ ] dot4 系命令は今の観測範囲では未検出
- [ ] まずは **非Xdlops / 非MLIR / 非強制** を安全地帯として扱う

---

## 1. 基本方針
- [ ] 自然選択を優先する
- [ ] 小さくて素直な shape から試す
- [ ] 「速い」より先に「完走・verify・再現性」を見る
- [ ] 危ない遊具（Xdlops/MLIR/DLOPS強制）は後回しにする

---

## 2. レベル1: 安全地帯を探す
### まず試す
- [ ] INT8 / NCHW / batch=1 / 1x1 / C=32 / K=32
- [ ] INT8 / NCHW / batch=1 / 3x3 / C=32 / K=32 / pad=1
- [ ] INT8 / NCHW / batch=1 / 3x3 / C=64 / K=64 / pad=1
- [ ] INT8 / NCHW / batch=4 / 3x3 / C=64 / K=64 / pad=1

### 見ること
- [ ] 完走するか
- [ ] verify OK か
- [ ] 選ばれた solver は何か
- [ ] naive 以外が自然選択されるか

---

## 3. レベル2: 境界を広げる
### 少しずつ増やす
- [ ] stride=2
- [ ] group=2
- [ ] C=128
- [ ] C=256
- [ ] spatial=64x64
- [ ] spatial=128x128
- [ ] batch=8
- [ ] 5x5

### 見ること
- [ ] どこから不安定になるか
- [ ] どこで naive 固定になるか
- [ ] solver が切り替わる境界はどこか
- [ ] channel / spatial / stride / group のどれが効くか

---

## 4. 今は乗せない遊具
- [ ] 強制 Xdlops
- [ ] 強制 MLIR
- [ ] 強制 DLOPS
- [ ] 強制 ASM v4r1 dynamic
- [ ] FP16/BFP16 の Xdlops 再挑戦（優先度低）

---

## 5. 毎回残すログ
- [ ] ケース名
- [ ] dtype
- [ ] layout
- [ ] N/C/H/W
- [ ] K/Y/X
- [ ] stride/pad/dilation/group
- [ ] solver 名
- [ ] verify 結果
- [ ] exit code
- [ ] エラーメッセージ
- [ ] 実行時環境変数
- [ ] MIOpen ログ
- [ ] 可能なら rocprofv3 trace
- [ ] 可能なら HSACO / 逆アセンブルメモ

---

## 6. 判定
### 安全
- [ ] 完走
- [ ] verify OK
- [ ] 再現する
- [ ] 強制なしで通る

### ようすみ
- [ ] 通るが naive のみ
- [ ] shape を変えると不安定
- [ ] solver が揺れる

### 危険
- [ ] memory access fault
- [ ] code object build failed
- [ ] MIIR_INVALID_PARAM
- [ ] assertion abort

---

## 7. 先に答えたい問い
- [ ] INT8 で naive 以外の安全な自然選択 solver はあるか
- [ ] あるならどの shape で出るか
- [ ] 危ないのは dtype なのか solver family なのか
- [ ] Vegaちゃんにとって INT8 は「安全だけど地道」なのか、それとも「条件次第で上手な道がある」のか

---

## 8. ひとことでいうと
- [ ] Vegaちゃんに、INT8 のおもちゃで **けがせず楽しく遊べる園庭** を見つけてあげる