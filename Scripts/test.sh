#!/bin/bash
# 使用与本地打包一致的 SDK，以 swiftc + XCTest 运行核心逻辑测试。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [ ! -d "$SDK_PATH" ]; then
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

cd "$ROOT"
mkdir -p "$BUILD_DIR"
find Sources/biaoqingb/Models Sources/biaoqingb/Services Tests/biaoqingbTests \
    -name '*.swift' -print0 | xargs -0 swiftc \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macosx13.0 \
    -o "$BUILD_DIR/core-tests"

"$BUILD_DIR/core-tests"
