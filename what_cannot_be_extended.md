# gfx900 で拡張・修正が困難な層

作成日: 2026-03-17
関連文書: `support_boundary.md §2.2-2.3`, `final_hypothesis.md §4 Q3`, `what_can_be_extended.md`（対文書）

> 本メモは、公開一次資料およびローカル clone から観測可能な範囲を整理したものであり、非公開 issue や社内意思決定の内容を断定するものではない。

---

## この文書の目的

gfx900 (Vega) において、コミュニティが技術的・組織的・物理的理由から変更しにくい層を、
**観測根拠とともに** 整理する。

「拡張・修正が困難」の分類:

| 種別 | 意味 |
|---|---|
| **物理制約** | ハードウェア ISA の不在。ソフトウェアで回避不可 |
| **非公開境界** | ソース・根拠が非公開で外部からアクセスできない |
| **組織的境界** | 技術的には変更可能だが、AMD の内部プロセスに依存する |

対文書 `what_can_be_extended.md` は「変更可能な層」を扱う。

---

## 1. ハードウェア命令セット（物理制約）

**内容**: gfx900 が物理的に持たない命令セットは、ソフトウェアでは補完できない。

**観測根拠（code_verified / runtime_verified）**:

| 能力 | gfx906 | gfx908 | gfx900 | 影響 |
|---|---|---|---|---|
| `v_dot4_i32_i8` (dot4) | あり | あり | **なし** | CK iGEMM の INT8 積和パスが成立しない |
| MFMA 命令群 | なし | あり | **なし** | XDLops 系 solver が成立しない |
| `v_mfma_*` / WMMA 等 | なし | あり | **なし** | 同上 |

**関連する除外観測（runtime_verified）**:

- `ConvHipImplicitGemmFwdXdlops` 強制実行: `std::vector::operator[]` assertion abort（EXIT=134）
- `ConvHipImplicitGemmForwardV4R5Xdlops` 強制実行: `intrin_mfma_*` compile 失敗 → `Code object build failed`（rc=0x7）
- `ConvCkIgemmFwdV6r1DlopsNchw` 強制実行: 全15+ケースで `not applicable`（rc=0x3）

**判断**: これらは「ソフトウェアの変更で回避できる制約」ではない。gfx900 への MFMA 追加は不可能。

---

## 2. GPU Firmware（非公開・配布チャネル分離）

**内容**: vega10 firmware（`vega10_*.bin.zst`）はバイナリブロブとして配布されており、
ソース非公開。修正・差し替えはコミュニティには困難。

**観測根拠（shipped_artifact_verified）**:
- `/lib/firmware/amdgpu/` に `vega10_*.bin.zst` 16ファイルが存在
- 配布チャネル: `linux-firmware` パッケージ（ROCm パッケージとは独立）
- ソース: AMD が kernel-mode で保持。OSS として公開されていない

**補足**: firmware の更新は AMD が管理する `linux-firmware` 経由での配布のみ。
コミュニティが firmware を独自修正する実績は一般的に存在しない。

---

## 3. MLIR iGEMM の gfx900 除外根拠（非公開 issue）

**内容**: `ConvMlirIgemmFwd::IsApplicable()` の gfx900 除外（`StartsWith("gfx900") return false`）は
コード上は変更可能だが、その根拠が非公開 issue に閉じている。

**観測根拠（code_verified / history_verified）**:

```cpp
// conv_mlir_igemm_fwd.cpp:188 (runtime_verified)
if (miopen::StartsWith(ctx.GetStream().GetDeviceName(), "gfx900"))
    return false;  // see llvm-project-private/issues/389
```

- 除外コミット: `2407d2f`（2021-12-22, Zhuoran Yin, AMD）
- 参照先: `llvm-project-private/issues/389`（AMD 社内非公開）
- 公開 `llvm/llvm-project` での同系統 issue は未発見（2026-03-15 時点）

**なぜ「困難」か**:

- コード行の削除は技術的に可能（`what_can_be_extended.md §1` 参照）
- しかし「除外された技術的理由」が不明なまま変更した場合、
  除外理由が解消していない問題（MLIR コンパイラのバグ等）が残存する可能性がある
- AMD がこの変更を upstream に採用するかも不明
- したがって「変更できる」と「安全に動く」の間に不確実性がある

**判断分類**: 物理制約ではなく「非公開境界」。根拠が公開されれば変更の障壁は下がりうる。

---

## 4. 公式 QA / CI / リリース判定（組織的境界）

**内容**: AMD の ROCm リリースプロセスにおける gfx900 の QA 対象・CI テスト対象・リリース判定は、
外部からアクセスできない組織的プロセスに依存する。

**観測根拠（shipped_artifact_verified / 未確認の組み合わせ）**:

| 観点 | 確認可能な状態 | 外部から確認不可 |
|---|---|---|
| サポートマトリクス | gfx900 は ROCm 7.2 公式リスト外 | 非掲載の具体的判断 |
| 出荷成果物 | rocBLAS / Perf DB / firmware は出荷継続 | 出荷判定プロセス |
| CI テスト | gfx900 対象の公開 CI ログは未確認 | 内部 CI 有無 |
| バグ受付 | gfx900 固有バグの処理方針は不明 | triaging 方針 |

**判断分類**: 技術的制約ではなく「組織的境界」。コミュニティが code を変更しても、
公式 QA プロセスに組み込まれるかどうかはコミュニティが単独で決定できない。

---

## 5. カーネルモードドライバ（AMDGPU KFD / KMS）

**内容**: ROCm の userspace library は、カーネルモードの `amdgpu` ドライバ（KFD / DRM）上で動作する。
このレイヤは技術的には変更可能な OSS（Linux kernel `drivers/gpu/drm/amdgpu/`）だが、
修正・配布の難度は userspace より大幅に高い。

**観測根拠（runtime_verified）**:
- `rocminfo` で `/dev/kfd` への認識を確認（gfx900 は現行カーネルドライバで認識される）
- gfx900 は現行 `amdgpu` ドライバで動作しており、この層については現時点で「変更が必要な問題」は観測されていない

**補足**: 現時点では gfx900 に関してカーネルドライバ側で問題は観測されていないため、
この層は「困難」というよりも「コストが高いが現時点では変更を要しない層」として位置づける。

---

## 6. INT8 向け高速積和経路の物理的制限

**内容**: gfx900 は `v_dot4_i32_i8` / `v_dot4_u32_u8` を持たないため、
INT8 の積和を「ソフトウェアで実装する」ことは可能だが、dot4 対応世代と同等の性能には達しない。

**観測根拠（code_verified / runtime_verified）**:
- gfx900 での INT8 conv で自然選択されるのは `ConvDirectNaiveConvFwd`（Naive solver）のみ（15+ケース全件）
- Naive solver は最適化なし設計（常時 applicable を目的とした基準実装）
- `hsaco_disassembly_notes.md` で gfx900 の HSACO は `v_mac_f32` / `v_mul_lo_u32` 等を使用していることを確認

**判断**: INT8 の「動く実装」は物理制約ではないが、INT8 の「高速な実装」は dot4 不在という物理制約に依存する。
`what_can_be_extended.md §7` で触れた ASM 拡張は「動くこと」までは可能でも、
「dot4 と同等の性能」は物理的に達成できない。

---

## 横断的な観測（Fact）

- **物理制約**: MFMA / dot4 不在は変更できない。これらに依存する solver は gfx900 では恒久的に成立しない
- **非公開境界**: MLIR iGEMM 除外の根拠は外部から確認できず、変更の安全性が評価困難
- **組織的境界**: QA / CI / リリース判定はコミュニティが単独で変更できる領域の外にある

---

## Open Question / Limitation

1. **MLIR iGEMM 除外の技術的根拠**: private #389 が公開された場合、除外の変更可能性の評価が変わる
2. **カーネルドライバの将来**: 現時点では gfx900 でドライバ問題は観測されていないが、将来のカーネルバージョンで変化しうる
3. **組織的境界の変動**: AMD が gfx900 の扱いを変更した場合（例: TheRock 移行に伴う方針変更）、組織的境界の位置が変わりうる

---

## 本文書が主張しないこと

- 「修正困難」な層が永続的に変更不可であるとは主張しない
- MLIR iGEMM の除外理由を推定で補完するものではない
- コミュニティが「修正困難な層」の変更を試みることを否定するものではない
- 特定組織や個人への評価を目的とするものではない
