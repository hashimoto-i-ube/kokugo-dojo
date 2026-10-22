# 国語道場（KokugoDojo）

高校国語・大学入試対策のための macOS 学習アプリです。高校入学程度から、旧帝大・医学部を含む難関大学の合格レベルまでを 5 段階で学べます。

| 分野 | 内容 |
|---|---|
| 漢字 | 読み・書き取り・同音異義語 |
| 語彙 | 評論重要語・慣用句／故事成語・四字熟語・小説の心情語 |
| 現代文読解 | 評論・小説の読解演習（縦書き本文＋設問）、読解技法 |
| 古文単語 | 重要古語 |
| 古典文法 | 用言の活用・助動詞・文法の識別・敬語・助詞、活用表などの解説、古文読解 |
| 漢文句法 | 句形・訓読練習（返り点・送り仮名付き縦書き）・重要語、漢文読解 |
| 基礎知識・文学史 | 古典／近現代文学史・古文常識・和歌の修辞・表現技法と論理 |

レベル：Lv.1 高校入門 / Lv.2 高校基礎 / Lv.3 共通テスト / Lv.4 難関大 / Lv.5 旧帝大・医学部

## 主な機能

- **縦書き表示**（ルビ・傍線・傍点・訓点に対応）。設定で横書きにも切り替え可能
- **間隔反復（SRS）**による復習スケジュール、カード学習と 4 択テスト
- 学習記録・連続学習日数・分野／レベル別の進捗表示
- **コンテンツの自動更新**：起動時に GitHub 上の `content/manifest.json` を確認し、新しい問題パックだけをダウンロード（SHA-256 で検証）
- **アプリ本体の更新通知**：GitHub Releases に新バージョンがあればサイドバーに表示
- 学習記録の保存先を外部ボリュームに変更可能（設定 → データ）

コンテンツは高等学校学習指導要領（平成30年告示）に準拠しています。改訂に備えた拡張方法は [docs/CONTENT_FORMAT.md](docs/CONTENT_FORMAT.md) を参照してください。

## ビルド

必要環境：macOS 14 以降、Xcode（Swift 6）、Python 3

```bash
scripts/build-app.sh
```

`build/国語道場.app` ができます。中間ファイルはすべてリポジトリ内（`.build/` `build/`）に作られます。

開発中の起動・テスト：

```bash
swift run KokugoDojo
```

```bash
swift test
```

特定の画面を直接開く（動作確認用）：`.build/debug/KokugoDojo -debugRoute study:kanji-read`
（`study:` `quiz:` `browse:` はデッキID、`passage:` `lesson:` はそれぞれのID、`subject:` は分野名）

Releases からダウンロードしたアプリはアドホック署名のため、初回は Finder で右クリック →「開く」を選ぶか、次を実行してください。

```bash
xattr -dr com.apple.quarantine /Applications/国語道場.app
```

## コンテンツの追加・修正

1. `content/src/` の原稿を編集（形式は [docs/CONTENT_FORMAT.md](docs/CONTENT_FORMAT.md)）
2. `python3 scripts/build_content.py` で JSON とマニフェストを再生成（変更したパックだけ版が上がる）
3. コミットして `main` に push → 利用者のアプリが次回起動時に取り込みます

## リリース

`VERSION` を更新してコミットし、`v0.2.0` のようなタグを push すると、GitHub Actions がアプリをビルドして Releases に zip を添付します。

## ディレクトリ構成

```
Sources/KokugoCore   データモデル・SRS・記法変換・更新処理（テスト対象）
Sources/KokugoDojo   SwiftUI の画面
content/src          コンテンツ原稿
content/packs        生成された問題パック（アプリ同梱・配信用）
scripts              コンテンツ生成・アプリ作成スクリプト
docs                 仕様・開発状況メモ
```
