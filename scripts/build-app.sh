#!/bin/zsh
# 国語道場.app を build/ に作成する。中間生成物はすべてリポジトリ内（.build/, build/）に置く。
#   scripts/build-app.sh            リリースビルド
#   scripts/build-app.sh --zip      配布用 zip も作成
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
VERSION=$(cat VERSION)
APP="build/国語道場.app"

# キャッシュ類も外部ボリューム上に置く（内蔵 SSD の消費を避ける）
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_CACHE_PATH="$ROOT/.build/swiftpm-cache"

python3 scripts/build_content.py --check
swift build -c release --product KokugoDojo --cache-path "$SWIFTPM_CACHE_PATH"
BIN=$(swift build -c release --product KokugoDojo --show-bin-path)/KokugoDojo

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/content"
cp "$BIN" "$APP/Contents/MacOS/KokugoDojo"
cp -R content/packs "$APP/Contents/Resources/content/packs"
cp content/manifest.json "$APP/Contents/Resources/content/"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>国語道場</string>
  <key>CFBundleDisplayName</key><string>国語道場</string>
  <key>CFBundleIdentifier</key><string>io.github.hashimoto-i-ube.kokugodojo</string>
  <key>CFBundleExecutable</key><string>KokugoDojo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>ja</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 署名（既定はアドホック。配布用には SIGN_IDENTITY を指定）
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"
echo "作成: $APP (v$VERSION)"

if [[ "${1:-}" == "--zip" ]]; then
  ditto -c -k --keepParent "$APP" "build/KokugoDojo-${VERSION}.zip"
  echo "作成: build/KokugoDojo-${VERSION}.zip"
fi
