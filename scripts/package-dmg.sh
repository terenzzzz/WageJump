#!/bin/zsh
# 打一个不会在 7 天后失效的 macOS 安装包。
# 使用 ad-hoc 签名，不嵌入 Apple 开发描述文件。对方首次打开需要右键「打开」。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DERIVED="$ROOT/build/DerivedData"
SIGNING="$ROOT/build/signing"
STAGE="$ROOT/build/dmg-stage"
DIST="$ROOT/dist"
APP_NAME="WageJump"

echo "==> 编译 Release（不使用 Apple Development 签名）"
xcodebuild \
  -project "$ROOT/WageJump.xcodeproj" \
  -scheme WageJump \
  -configuration Release \
  -sdk macosx \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  build

BUILT="$DERIVED/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$BUILT" ]]; then
  echo "找不到编译产物: $BUILT" >&2
  exit 1
fi

mkdir -p "$SIGNING"

make_distribution_entitlements() {
  local source="$1"
  local dest="$2"
  cp "$source" "$dest"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$dest" 2>/dev/null || true
}

APP_ENT="$SIGNING/WageJump.dist.entitlements"
WIDGET_ENT="$SIGNING/WageJumpWidget.dist.entitlements"
make_distribution_entitlements "$ROOT/WageJump/WageJump.entitlements" "$APP_ENT"
make_distribution_entitlements "$ROOT/WageJumpWidget/WageJumpWidget.entitlements" "$WIDGET_ENT"

echo "==> ad-hoc 签名（没有开发者证书，也没有 7 天描述文件）"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$BUILT" "$STAGE/$APP_NAME.app"
APP="$STAGE/$APP_NAME.app"

find "$APP" \( -name "embedded.provisionprofile" -o -name "embedded.mobileprovision" \) -delete

sign_item() {
  local entitlements="$1"
  local target="$2"
  codesign --force --sign - \
    --timestamp=none \
    --entitlements "$entitlements" \
    "$target"
}

while IFS= read -r appex; do
  sign_item "$WIDGET_ENT" "$appex"
done < <(find "$APP" -name "*.appex" -type d)

sign_item "$APP_ENT" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"
ln -sfn /Applications "$STAGE/Applications"

echo "==> 绘制安装窗口背景"
BG_DIR="$ROOT/build/dmg-background"
BG_2X="$BG_DIR/background@2x.png"
BG="$BG_DIR/background.jpg"
swift "$ROOT/scripts/render-dmg-background.swift" "$BG_2X"
# 访达会忽略带透明通道的 PNG。用 2x JPEG，Retina 上才能铺满整个窗口。
sips -s format jpeg -s formatOptions 92 -s dpiWidth 144 -s dpiHeight 144 "$BG_2X" --out "$BG" >/dev/null

echo "==> 打包 DMG"
mkdir -p "$DIST"
DMG="$DIST/WageJump-${VERSION}.dmg"
RW_DMG="$ROOT/build/WageJump-rw.dmg"
rm -f "$DMG" "$RW_DMG"
if mount | grep -q "on /Volumes/WageJump "; then
  hdiutil detach "/Volumes/WageJump" || hdiutil detach -force "/Volumes/WageJump"
fi

hdiutil create -size 80m -fs HFS+ -volname "WageJump" "$RW_DMG" >/dev/null
ATTACHED="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk 'END {print $1}')"
VOLUME="/Volumes/WageJump"

ditto "$APP" "$VOLUME/$APP_NAME.app"
ln -sfn /Applications "$VOLUME/Applications"
mkdir -p "$VOLUME/.background"
cp "$BG" "$VOLUME/.background/background.jpg"

# 背景文件夹必须先可见。访达不接受带透明通道的 PNG，所以用 JPEG。
osascript <<'EOF'
tell application "Finder"
  tell disk "WageJump"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {80, 60, 800, 640}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    delay 1
    set background picture of viewOptions to POSIX file "/Volumes/WageJump/.background/background.jpg"
    delay 1
    set position of item "WageJump.app" of container window to {196, 330}
    set position of item "Applications" of container window to {524, 330}
    update without registering applications
    delay 4
    close
  end tell
end tell
EOF

chflags hidden "$VOLUME/.background"
sync
hdiutil detach "$ATTACHED" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW_DMG"

echo "完成: $DMG"
