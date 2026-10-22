# 開発状況（中断・再開用メモ）

最終更新: 2026-10-22

## 完了
- アプリ骨格（SwiftPM: KokugoCore ライブラリ + KokugoDojo 実行ファイル）
  - 縦書き表示（WKWebView, writing-mode: vertical-rl）・ルビ・傍線・傍点・空欄・訓点（送り仮名／返り点）
  - SRS（SM-2 簡略版）・カード学習／4択テスト・読解演習・解説ページ・設定（縦横切替、文字サイズ、レベル範囲、保存先）
  - コンテンツ更新（GitHub 上の content/manifest.json を取得、SHA-256 検証）／アプリ更新確認（GitHub Releases）
- コンテンツ生成スクリプト scripts/build_content.py、アプリ作成 scripts/build-app.sh
- コンテンツ: 漢字 411・語彙 271・古文単語 231・古典文法 196（解説3）・漢文 170（解説1、訓点表示確認済み）

## 未完了（この順で進める）
1. 漢文の読解演習（passages）
4. 基礎知識・文学史（knowledge）
5. 現代文読解（オリジナル評論・小説の本文と設問）
6. README / docs/CONTENT_FORMAT.md / GitHub Actions（CI・リリース）
7. GitHub リポジトリ作成（公開/非公開を利用者に確認してから）

## 動作確認の方法
- `swift build && .build/debug/KokugoDojo -debugRoute study:kanji-read`（任意画面を直接開く）
- `swift test`（Markup・SRS・同梱パックの読み込み検査）
