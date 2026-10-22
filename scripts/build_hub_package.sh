#!/bin/bash
# ULSハブ用パッケージ（zip）を作る。
#   scripts/build_hub_package.sh [build番号]    例: scripts/build_hub_package.sh 2026102301
# build を省略すると「今日の日付＋連番(01〜)」を dist/hub から数えて自動で決める。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
if [ $# -ge 1 ]; then
  BUILD="$1"
else
  today="$(date +%Y%m%d)"; n=1
  while [ -e "dist/hub/kokugo-dojo-${today}$(printf '%02d' $n).zip" ]; do n=$((n + 1)); done
  BUILD="${today}$(printf '%02d' $n)"
fi
case "$BUILD" in ''|*[!0-9]*) echo "build は整数で指定してください: $BUILD" >&2; exit 1;; esac

python3 scripts/build_content.py --check >/dev/null || { echo "content の生成物が古いです。python3 scripts/build_content.py を実行してください" >&2; exit 1; }

STAGE="dist/hub/stage"
OUT="dist/hub/kokugo-dojo-${BUILD}.zip"
rm -rf "$STAGE"; mkdir -p "$STAGE/content"
cp hub/index.html hub/style.css hub/app.js hub/markup.js hub/hub-bridge.js hub/icon.png "$STAGE/"
cp -R content/packs "$STAGE/content/packs"
cp content/manifest.json "$STAGE/content/manifest.json"
sed -e "s/__VERSION__/${VERSION}/" -e "s/__BUILD__/${BUILD}/" hub/tool.json > "$STAGE/tool.json"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$STAGE/tool.json"

rm -f "$OUT"
(cd "$STAGE" && zip -qrX "../$(basename "$OUT")" tool.json index.html style.css app.js markup.js hub-bridge.js icon.png content)
rm -rf "$STAGE"

echo "作成: $OUT"
echo "build:  $BUILD"
echo "version: $VERSION"
echo "SHA-256: $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
echo "サイズ: $(stat -f%z "$OUT") bytes"
