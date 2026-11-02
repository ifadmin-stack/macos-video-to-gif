# 表情包工厂

一款原生 macOS 视频转 GIF 表情包制作工具。选段、裁剪、定时文字、播放效果和导出设置都会进入同一套真实 GIF 渲染流程，预览所见即导出所得。

## 功能

- 通过文件选择器或拖放导入视频，使用缩略图时间轴选段并逐帧微调。
- 拖动裁剪框调整画面范围。
- 添加多条定时文字，设置位置、字号、颜色和描边。
- 调整帧率、输出宽度、播放速度和循环方式，支持倒放与来回循环。
- 生成真实 GIF 预览，检查动画、文字、画质和实际文件大小。
- 按目标体积自动降低宽度或帧率，最多尝试 5 次；无法达标时会明确提示。
- 导出后复制 GIF、调用系统分享，或在 Finder 中显示文件。

## 环境要求

- macOS 13 或更高版本。
- Apple Silicon（`arm64`）Mac；当前构建脚本的目标为 `arm64-apple-macosx13.0`。
- Command Line Tools for Xcode，提供 Swift 编译器和 macOS SDK。

不需要完整 Xcode、SwiftPM 依赖或其他第三方工具。若尚未安装命令行工具，可运行 `xcode-select --install`。

## 快速开始

```bash
git clone https://github.com/ifadmin-stack/biaoqingb.git
cd biaoqingb
./setup.sh
open "build/表情包工厂.app"
```

`setup.sh` 会检查平台与 Swift 工具链，然后调用项目现有的构建脚本。应用使用 ad-hoc 签名，仅供本地运行；不会自动安装到 `/Applications`。

## 构建与测试

```bash
# 一键检查环境并构建
./setup.sh

# 仅重新构建
bash Scripts/make-app.sh

# 编译并运行核心逻辑与 GIF 集成测试
bash Scripts/test.sh

# 构建用于手动 UI 验证的独立 QA 应用
bash Scripts/make-qa-app.sh
open "build/qa/表情包工厂QA.app" --args --qa-video /absolute/path/to/video.mov
```

构建产物位于 `build/`。测试会通过 AVFoundation 生成临时视频，无需下载测试素材。

## 使用

1. 打开应用，选择视频或将视频拖入窗口。
2. 在时间轴上调整开始和结束位置；需要时使用逐帧按钮和画面裁剪。
3. 在“文字”页添加文字，并设置每条文字的显示时间与样式。
4. 在“导出”页设置帧率、宽度、速度、播放方式、循环和目标体积。
5. 在“GIF 预览”页生成真实动画预览，确认效果后导出 GIF。
6. 导出完成后可复制、分享文件，或在 Finder 中显示。

目标体积是压缩目标而非绝对保证。若自动压缩后仍超标，可缩短选段，或手动降低帧率、宽度。

## 项目结构

```text
Sources/biaoqingb/
├── BiaoQingBApp.swift       # 应用入口与全局状态注入
├── Models/                  # 应用状态、文字、导出配置与播放时间轴
├── Services/                # 抽帧编码、位图渲染、缩略图与系统分享
└── Views/                   # SwiftUI 播放器、时间轴、裁剪及各功能面板
Tests/
├── biaoqingbTests/          # 核心逻辑与真实 GIF 集成测试
└── UIQA/                    # 复用生产界面的独立 QA 入口
Resources/                   # Info.plist 与应用图标
Scripts/                     # 构建、测试和 QA 打包脚本
```

更多面向开发工作的命令与架构说明见 [CLAUDE.md](CLAUDE.md)。

## Using with Claude Code

项目包含 `CLAUDE.md`，Claude Code 启动时会自动读取其中的构建命令、架构和关键文件说明。

```bash
claude
```

## 贡献

欢迎提交 Issue 和 Pull Request，流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE) © 2026 biaoqingb contributors
