# コンテンツ原稿の書き方

学習コンテンツは `content/src/<パック>/` に原稿として置き、`scripts/build_content.py` で
アプリが読む `content/packs/*.json` と配信用 `content/manifest.json` を生成します。
**原稿を直したら必ずスクリプトを実行し、生成物ごとコミットしてください**（CI が検査します）。

```
content/src/
  meta.json                  学習指導要領・最低アプリバージョン
  <pack>/pack.json           パックID・分野(subject)・タイトル・curriculum
  <pack>/*.deck              問題集（1ファイル＝1デッキ）
  <pack>/lessons/*.html      解説ページ
  <pack>/passages/*.json     読解演習（本文＋設問）
```

## デッキ（.deck）

先頭の `#キー: 値` がデッキ情報、以降 1 行 1 問。列は「前後に空白のある `|`」で区切ります。

```
#id: kanji-read                 デッキID（全パックで一意。変更すると学習記録が引き継がれない）
#title: 漢字の読み
#kind: flash                    flash＝表裏カード / choice＝作成者指定の選択肢
#instruction: 傍線部の読みを答えよ。
#writing: horizontal            省略時は利用者の縦横設定に従う
#kanbun: true                   問題文を訓点付き漢文として描画
level | prompt | answer | note | distractors | id
2 | 計画を[[遂行]]する | すいこう | 解説 |
```

- `level`: 1＝高校入門 / 2＝高校基礎 / 3＝共通テスト / 4＝難関大 / 5＝旧帝大・医学部
- `distractors`: 誤答をセミコロン `;` 区切りで（choice は 2 つ以上必須）
- `id`: 省略時は「デッキID＋問題・答えのハッシュ」。**問題文や答えを直すと ID が変わり、その問題の学習記録はリセットされます。** 記録を残したまま文言を直したいときは、旧 ID（`content/packs/*.json` で確認）を `id` 列に書いてください。

## インライン記法

| 記法 | 意味 |
|---|---|
| `{漢字\|かんじ}` | ルビ |
| `[[本文]]` / `[[本文\|ア]]` | 傍線（記号付き） |
| `**本文**` | 傍点 |
| `__A__` | 空欄 |
| 空行 | 段落 |

漢文モード（`#kanbun: true` または passage の `"kanbun": true`）では、漢字の直後に
`（カタカナ）` で送り仮名、`〔レ〕` `〔一〕` `〔一レ〕` などで返り点を書きます。

```
学（ビテ）而時（ニ）習（フ）〔レ〕之（ヲ）
為（ル）〔二〕人（ノ）所（ト）〔一レ〕笑（フ）
```

## 解説ページ（lessons/*.html）

先頭に次のコメントを置き、その後に HTML 断片（`h2` `table` `ul` など）を書きます。

```html
<!--
id: lesson-doshi
title: 動詞の活用
level: 1
-->
```

## 読解演習（passages/*.json）

`id` `title` `genre` `level` `text`（段落の配列）`questions`（`prompt` `choices` `answer`=正解の添字 `explanation`）、
任意で `source` `commentary` `kanbun`。選択肢はアプリ側で毎回並べ替えるので、解説で「ア」「イ」など選択肢の位置に触れないでください。

## 著作権

現代文の本文は**書き下ろし**か、著作権の切れた作品に限ります。入試問題や市販教材の文章を転載しないでください。古典（古文・漢文）の原文は利用可能です。

## 学習指導要領の改訂に備えて

各パックの `curriculum`（現行は `H30`＝平成30年告示）と `content/src/meta.json` を更新します。
新課程向けにパックを分けたい場合は、別 ID のパック（例 `kanji-r12`）を作り、旧パックは残したまま段階的に移行できます。
アプリの読み込み形式を変える場合は `ContentPack.supportedSchema` と `schemaVersion` を上げ、
`meta.json` の `minAppVersion` を新アプリのバージョンにします（古いアプリは新形式のパックを取り込みません）。
