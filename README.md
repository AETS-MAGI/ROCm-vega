# vega investigations index

このディレクトリの運用方針は次の通り。

- 推論経路の最終判定は生コードを真実源とする。
- 参考リサーチは補助情報として扱う。
- 直接の推論経路情報は vega-rocm.md に集約する。
- 推論経路以外の背景情報はこの README に集約する。

## ドキュメント対応

- 推論経路トレース本体: vega-rocm.md
- 仮説整理: hypothesis.md
- GitHub履歴調査: rocm-github-investigate.md
- 逆アセンブル手順: disassemble_rocm.md
- 実行補助スクリプト: run_vega_path_case.sh
- MIIRトレース補助: run_vega_path_case_miir_trace.sh
- ローカルrocMLIRビルド: tools/build_rocmlir_local.sh
- ローカルrocMLIRビルド（detached起動）: tools/start_rocmlir_build_detached.sh
- ローカルMIOpen差し替え実行: tools/run_case_with_local_miopen.sh
- ローカルDebug版MIOpenビルド: tools/build_miopen_debug_local.sh
- 再ビルド手順メモ: miopen_debug_rebuild_plan.md

## 参考リサーチ吸収メモ（非推論経路）

以下は旧 Gemini リサーチ文書から移した背景メモ。
この節はコード未照合の項目を含むため、結論の根拠には使わない。

### 1) エコシステム背景

- ROCm 7.2 以降は新世代アーキテクチャへの最適化比重が高い。
- 旧世代を含む運用では、公式サポートとコミュニティ運用の間にギャップが出やすい。

### 2) RDNA系の観測ポイント（背景）

- RDNA4 系はネイティブ最適化の対象として扱われる一方、初期運用で個別不具合報告がある。
- RDNA2 系ではソフトウェア的な代替経路や最適化が議論されるが、本ノートでは背景情報扱い。

### 3) MIGraphX や上位フレームワークの位置づけ

- 上位レイヤーの設定や EP 選択は重要だが、本調査ワークツリーでは未監査領域がある。
- 実証には当該リポジトリの追加監査が必要。

### 4) 科学計算系スタック

- LAMMPS/GROMACS などの経路情報は有益だが、本調査の主題である gfx900 推論経路とは分離する。
- 必要時は別ノートを作成し、推論経路ノートに混在させない。

## 監査ルール

- code verified: 生コードで分岐や条件を確認済み。
- runtime verified: 実機実行やログ採取で動作・失敗モードを確認済み。
- history verified: `git blame` / `git log` / changelog など履歴情報で確認済み。
- hypothesis: 観測を踏まえた解釈・推論。未確定を含む。
- hint only: 参考情報のみでコード未確認。
- out of scope: この調査の主題外。

詳細な仕分け表は vega-rocm.md の第15節を参照。
