import SwiftUI
import AppKit

/// 导出参数、真实体积结果与任务控制。
struct ExportPanel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出设置").font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("帧率")
                        Slider(value: $state.fps, in: 5...24, step: 1)
                        Text("\(Int(state.fps)) fps")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }

                    HStack {
                        Text("宽度")
                        Slider(value: $state.maxWidth, in: 160...640, step: 20)
                        Text("\(Int(state.maxWidth)) px")
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                    }

                    Picker("播放速度", selection: $state.playbackSpeed) {
                        Text("0.25×").tag(0.25)
                        Text("0.5×").tag(0.5)
                        Text("1×").tag(1.0)
                        Text("1.5×").tag(1.5)
                        Text("2×").tag(2.0)
                        Text("3×").tag(3.0)
                    }

                    Picker("播放方式", selection: $state.playbackMode) {
                        ForEach(GIFPlaybackMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("无限循环播放", isOn: $state.loopForever)

                    Divider()

                    Toggle("限制导出文件大小", isOn: $state.targetSizeEnabled)
                    if state.targetSizeEnabled {
                        Picker("目标体积", selection: $state.targetSizeMB) {
                            Text("不超过 1 MB").tag(1.0)
                            Text("不超过 2 MB").tag(2.0)
                            Text("不超过 5 MB").tag(5.0)
                            Text("不超过 10 MB").tag(10.0)
                        }
                    }

                    Text(estimateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(state.isProcessing)
            }

            Divider()

            if state.isExporting {
                ProgressView(value: state.exportProgress) {
                    Text("导出中… \(Int(state.exportProgress * 100))%")
                }
                Button(state.isCancelling ? "正在取消…" : "取消导出", role: .cancel) {
                    state.cancelProcessing()
                }
                .disabled(state.isCancelling)
            } else {
                Button(action: state.exportGIF) {
                    Label("导出 GIF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.videoURL == nil || state.trimDuration <= 0 || state.isProcessing)
            }

            if let result = state.lastExportResult {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(result.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Button(action: state.copyExportedGIF) {
                            Label(
                                state.didCopyExportedGIF ? "已复制" : "复制 GIF",
                                systemImage: state.didCopyExportedGIF ? "checkmark" : "doc.on.doc"
                            )
                        }

                        ShareLink(item: result.url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }

                        Spacer()
                        Button("显示") {
                            NSWorkspace.shared.activateFileViewerSelecting([result.url])
                        }
                        .controlSize(.small)
                    }

                    Text("实际大小：\(formatBytes(result.fileSizeBytes))")
                    Text("输出：\(result.configuration.maxWidth) px · \(Int(result.configuration.fps)) fps")

                    if !result.targetWasMet {
                        Label(
                            "自动压缩后仍未低于目标体积。可缩短选段，或降低帧率、宽度后重试。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var estimateText: String {
        if state.targetSizeEnabled {
            return "将根据真实文件大小自动降低宽度或帧率，最多尝试 5 次；极端内容可能无法达到目标。"
        }

        let width = state.maxWidth
        var height = state.videoSize.height > 0
            ? width * state.videoSize.height / max(1, state.videoSize.width)
            : width * 9 / 16
        if state.cropEnabled, state.cropRect.width > 0 {
            height = width * state.cropRect.height / state.cropRect.width
        }
        let frames = state.outputFrameCount
        let megabytes = width * height * Double(frames) * 0.12 / 1_000_000
        var text = String(format: "粗略预估约 %.1f MB（%d 帧），以实际导出为准。", megabytes, frames)
        if megabytes > 5 { text += " 体积偏大，建议开启大小限制。" }
        return text
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
