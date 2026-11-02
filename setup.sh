#!/usr/bin/env bash
set -euo pipefail

# 表情包工厂 — 检查本地构建环境并生成 .app
# Usage: ./setup.sh

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "=== 表情包工厂 Setup ==="

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Error: 此项目仅支持 macOS。" >&2
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "Error: 当前构建脚本仅支持 Apple Silicon（arm64）Mac。" >&2
  exit 1
fi

for tool in swiftc xcrun xcode-select; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: 缺少 $tool。请先运行 xcode-select --install 安装命令行工具。" >&2
    exit 1
  fi
done

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Error: 未配置开发者工具。请运行 xcode-select --install。" >&2
  exit 1
fi

if ! SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null)" || [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
  echo "Error: 未找到 macOS SDK。请安装或重新配置 Command Line Tools for Xcode。" >&2
  exit 1
fi

if [ ! -f "$ROOT/Scripts/make-app.sh" ]; then
  echo "Error: 缺少 Scripts/make-app.sh，无法构建。" >&2
  exit 1
fi

echo "Platform: macOS / arm64"
echo "Swift: $(swiftc --version | head -n 1)"
echo "SDK: $SDK_PATH"
echo "Building 表情包工厂.app..."

bash "$ROOT/Scripts/make-app.sh"

APP_PATH="$ROOT/build/表情包工厂.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: 构建命令结束，但未找到 $APP_PATH" >&2
  exit 1
fi

echo ""
echo "=== Setup complete! ==="
echo "运行: open \"$APP_PATH\""
echo "测试: bash \"$ROOT/Scripts/test.sh\""
echo "Using Claude Code? CLAUDE.md has all the context."
