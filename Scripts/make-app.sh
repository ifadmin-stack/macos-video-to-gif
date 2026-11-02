#!/bin/bash
# 本地打包脚本：swiftc 直接编译 → 表情包工厂.app
# 仅自用，ad-hoc 签名，无需开发者账号、无需完整 Xcode
set -euo pipefail

APP_NAME="表情包工厂"
EXECUTABLE="biaoqingb"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/${APP_NAME}.app"
BUILD_DIR="$ROOT/build"

cd "$ROOT"

# 注意：系统 27.0 SDK 将 SwiftUI 的 @State 等实现为宏，
# 其编译插件只随完整 Xcode 分发，CLT 环境无法解析。
# 因此固定使用 26.5 SDK 编译（对运行 macOS 27 无影响，向前兼容）。
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ ! -d "$SDK_PATH" ]; then
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

echo "==> 编译（release，swiftc）"
mkdir -p "$BUILD_DIR"
find Sources -name '*.swift' -print0 | xargs -0 swiftc \
    -O -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macosx13.0 \
    -o "$BUILD_DIR/${EXECUTABLE}"

echo "==> 组装 .app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BUILD_DIR/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
mkdir -p "$APP_DIR/Contents/Resources"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "==> ad-hoc 签名（本地运行用）"
codesign --force --sign - "$APP_DIR" 2>/dev/null || true

echo "==> 完成：$APP_DIR"
echo "    运行：open \"$APP_DIR\""
echo "    或拖到 /Applications 长期使用"
