#!/bin/bash
# 构建独立 QA 应用；不会修改正式应用或其启动逻辑。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/qa/表情包工厂QA.app"
BUILD_DIR="$ROOT/build/qa"
EXECUTABLE="biaoqingb"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ ! -d "$SDK_PATH" ]; then
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

cd "$ROOT"
mkdir -p "$BUILD_DIR"
{
    find Sources -name '*.swift' ! -name 'BiaoQingBApp.swift'
    printf '%s\n' Tests/UIQA/UIQAApp.swift
} | tr '\n' '\0' | xargs -0 swiftc \
    -O -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macosx13.0 \
    -o "$BUILD_DIR/${EXECUTABLE}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.local.biaoqingb.qa' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName 表情包工厂QA' "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string 表情包工厂QA' "$APP_DIR/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName 表情包工厂QA' "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR" 2>/dev/null || true

echo "$APP_DIR"
