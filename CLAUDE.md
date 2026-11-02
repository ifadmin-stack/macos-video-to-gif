# 表情包工厂（biaoqingb）

**Version:** 0.1.0 | **Platform:** macOS 13+ / arm64 | **Stack:** Swift, SwiftUI, AppKit, AVFoundation, ImageIO

## What

原生 macOS 视频转 GIF 工具，支持选段、裁剪、多条定时文字、真实 GIF 预览、播放效果、目标体积、复制与系统分享。无第三方依赖，无服务端或端口。

## Quick Start

```bash
./setup.sh                         # 检查环境并构建应用
open "build/表情包工厂.app"        # 启动应用
bash Scripts/test.sh               # 运行核心与 GIF 集成测试
```

## Commands

```bash
# Prerequisites: macOS 13+, Apple Silicon, Command Line Tools for Xcode
xcode-select --install             # 仅在尚未安装 CLT 时运行

# Build and run
bash Scripts/make-app.sh            # swiftc release 编译、组装 .app、ad-hoc 签名
open "build/表情包工厂.app"

# Tests
bash Scripts/test.sh                # 编译 Models、Services 和测试入口后执行

# Manual UI QA with a known video
bash Scripts/make-qa-app.sh
open "build/qa/表情包工厂QA.app" --args --qa-video /absolute/path/to/video.mov
```

构建脚本优先使用 CLT 的 `MacOSX26.5.sdk`（若存在），否则使用 `xcrun --show-sdk-path`。没有 `.env`、依赖安装、Docker 或数据库步骤。

## Architecture

```text
Sources/biaoqingb/
├── BiaoQingBApp.swift   # @main，创建 AppState 并注入视图
├── Models/              # AppState、Caption、导出参数、帧采样与取消状态
├── Services/            # 视频抽帧、GIF 编码、渲染、缩略图、剪贴板
└── Views/               # SwiftUI/AppKit 界面与交互
Tests/
├── biaoqingbTests/      # 自定义测试入口、单元测试和真实 GIF 集成测试
└── UIQA/                # 独立 QA 应用入口，复用生产 UI
Resources/               # Info.plist 与 AppIcon.icns
Scripts/                 # 直接调用 swiftc 的构建和测试脚本
```

`AppState` 集中管理当前视频和编辑参数，并生成 `GIFExportConfiguration`。`GIFExporter` 用 AVFoundation 抽帧、ImageIO 编码；预览和导出共用 `GIFRenderer` 完成缩放与文字绘制。目标体积模式按实际文件大小迭代降低质量，SwiftUI 通过状态回调显示进度与结果。

## Key Files

```text
Sources/biaoqingb/Models/AppState.swift                 # 全局工作流与任务状态
Sources/biaoqingb/Models/GIFExportConfiguration.swift  # 导出参数、降质策略、取消同步
Sources/biaoqingb/Models/GIFPlayback.swift             # 正常、倒放、来回循环采样
Sources/biaoqingb/Services/GIFExporter.swift           # 抽帧、编码、目标体积与原子提交
Sources/biaoqingb/Services/GIFRenderer.swift           # 预览/导出共用的图像渲染
Sources/biaoqingb/Services/GIFSharing.swift            # GIF 剪贴板写入与失败恢复
Sources/biaoqingb/Views/ContentView.swift              # 主界面、拖放和视频区域
Sources/biaoqingb/Views/ExportPanel.swift              # 导出参数、结果、复制与分享
Scripts/make-app.sh                                    # 正式应用构建参数
Scripts/test.sh                                        # 测试编译范围与执行入口
```

## Development Notes

- 保持 Swift 4 空格缩进；核心逻辑放在 Models/Services，UI 放在 Views。
- 修改渲染或导出行为时运行 `bash Scripts/test.sh`；修改交互时同时使用 QA 应用手动验证。
- 构建产物写入 `build/`，已由 `.gitignore` 排除。

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
