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
cat > "$STAGE/请先读我.txt" <<EOF
WageJump ${VERSION}

这个安装包没有使用 Apple 开发者签名，也没有嵌入会在 7 天后过期的开发描述文件。
macOS 无法确认开发者身份，第一次打开需要手动放行。

安装：
1. 把 WageJump 拖到右边的「应用程序」文件夹。
2. 打开「应用程序」，对 WageJump 点右键，选择「打开」。
3. 如果仍然被拦截，到「系统设置 → 隐私与安全性」里点「仍要打开」。
EOF

ln -sfn /Applications "$STAGE/Applications"

echo "==> 打包 DMG"
mkdir -p "$DIST"
DMG="$DIST/WageJump-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create \
  -volname "WageJump" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "完成: $DMG"
