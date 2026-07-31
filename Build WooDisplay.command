#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="WooDisplay"
APP_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$PROJECT_DIR/Assets/AppIcon.icns"
CSV_SOURCE="$PROJECT_DIR/wc-product-export-30-7-2026-1785460675095.csv"

cd "$PROJECT_DIR"

echo "Building WooDisplay…"
ARM_BUILD_DIR="$PROJECT_DIR/.build-arm"
X86_BUILD_DIR="$PROJECT_DIR/.build-x86"
mkdir -p "$ARM_BUILD_DIR/clang-module-cache" "$X86_BUILD_DIR/clang-module-cache"
if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]]; then
  export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
fi

export CLANG_MODULE_CACHE_PATH="$ARM_BUILD_DIR/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ARM_BUILD_DIR/clang-module-cache"
swift build -c release --disable-sandbox --arch arm64 --build-path "$ARM_BUILD_DIR"

export CLANG_MODULE_CACHE_PATH="$X86_BUILD_DIR/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$X86_BUILD_DIR/clang-module-cache"
swift build -c release --disable-sandbox --arch x86_64 --build-path "$X86_BUILD_DIR"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo -create \
  "$ARM_BUILD_DIR/arm64-apple-macosx/release/WooDisplay" \
  "$X86_BUILD_DIR/x86_64-apple-macosx/release/WooDisplay" \
  -output "$MACOS_DIR/WooDisplay"
chmod 755 "$MACOS_DIR/WooDisplay"
install -m 644 "$CSV_SOURCE" "$RESOURCES_DIR/catalogue.csv"
install -m 644 "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "$ICON_SOURCE" ]]; then
  install -m 644 "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"
touch "$APP_DIR"

echo
echo "WooDisplay.app is ready."
echo "You can close this window and double-click the app."
read -k 1 "?Press any key to close…"
