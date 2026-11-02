# 贡献指南

感谢你为表情包工厂贡献代码、文档或问题反馈。

## 开发环境

请准备 macOS 13+、Apple Silicon Mac 和 Command Line Tools for Xcode。项目不需要完整 Xcode 或第三方依赖。

```bash
git clone https://github.com/ifadmin-stack/macos-video-to-gif.git
cd macos-video-to-gif
./setup.sh
bash Scripts/test.sh
open "build/表情包工厂.app"
```

详细架构和关键文件说明见 [CLAUDE.md](CLAUDE.md)。

## 分支与 Pull Request

1. Fork 仓库，并从最新 `main` 创建聚焦单一目标的分支，例如 `fix/gif-loop` 或 `feature/caption-style`。
2. 保持改动精简，避免无关格式化、重命名或生成文件变更。
3. 为行为修复或新功能补充合适的测试，并更新受影响的文档。
4. 提交前运行 `bash Scripts/test.sh` 和 `git diff --check`。
5. 提交 Pull Request，说明动机、主要改动、验证结果，以及任何未覆盖的风险。界面改动请描述手动验证步骤；如维护者需要，可提供相关截图。

不要提交 `build/`、导出的 GIF、个人配置或包含隐私信息的视频素材。

## 代码约定

- 使用 Swift 4 空格缩进，沿用现有类型、方法和文件组织方式。
- 视图放在 `Sources/biaoqingb/Views/`，状态和值模型放在 `Models/`，编码、渲染及系统服务放在 `Services/`。
- 预览与正式导出必须继续共用渲染流程，避免两条路径产生不同结果。
- 导出错误、取消状态和目标体积结果应如实呈现，不要以静默回退掩盖失败。
- 修改 SwiftUI 交互后，除自动测试外还应构建应用进行手动验证。需要固定测试视频时可使用 `Scripts/make-qa-app.sh`。

## 报告问题

请通过 GitHub Issues 提交 bug 或功能建议，并尽量使用对应模板。Bug 报告应包含：

- macOS 版本、Mac 芯片和 `swiftc --version` 输出。
- 清晰的复现步骤、预期结果与实际结果。
- 可公开分享的错误信息或日志。
- 与视频格式、选段、裁剪、文字或导出参数相关的最小复现配置。

请勿上传无权分享的视频，也不要在 Issue 中提交私人文件或敏感信息。

## Using with Claude Code

本仓库的 `CLAUDE.md` 提供已核对的构建、测试命令和架构上下文。使用 Claude Code 时，请在仓库根目录启动 `claude`，并在提交前独立检查变更和测试结果。
