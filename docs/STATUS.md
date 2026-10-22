# 開発状況（中断・再開用メモ）

最終更新: 2026-10-22

## 完了
- アプリ本体（SwiftPM: KokugoCore + KokugoDojo）：縦書き（ルビ・傍線・傍点・空欄・訓点）、SRS、カード学習／4択テスト、読解演習（選択肢シャッフル）、解説ページ、設定、コンテンツ自動更新、アプリ更新通知
- コンテンツ 1,529 項目：漢字 411・語彙 271・古文単語 231・古典文法 196・漢文 170・基礎知識 234・読解技法 16、読解演習 7 本（評論3・小説2・古文1・漢文1）、解説 6
- scripts/build_content.py（原稿→JSON・マニフェスト）、scripts/build-app.sh（.app 作成）
- README、docs/CONTENT_FORMAT.md、GitHub Actions（CI・タグでリリース）

## 次にやること
1. （完了）公開リポジトリ https://github.com/hashimoto-i-ube/kokugo-dojo を作成・push済み。CI 通過。v0.1.0 のリリースタグは未作成
2. コンテンツ拡充（特に Lv.4〜5 の漢字・古文単語、読解演習の本数、古文・漢文読解、共通テスト形式の複数テクスト問題）
3. アプリアイコン（Resources/AppIcon.icns）
4. 記述式答案の自己採点モード（国公立二次対策）

## 動作確認の方法
- `swift build && .build/debug/KokugoDojo -debugRoute study:kanji-read`（任意画面を直接開く）
- `swift test`（Markup・SRS・同梱パックの読み込み検査）
