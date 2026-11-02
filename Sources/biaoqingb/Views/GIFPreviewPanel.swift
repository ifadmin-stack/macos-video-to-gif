import SwiftUI
import AppKit

struct GIFPreviewPanel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("真实 GIF 预览").font(.headline)

            if let url = state.previewURL {
                AnimatedGIFView(url: url)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text("生成后可检查文字、帧率和画质")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color.black.opacity(0.04))
                .cornerRadius(8)
            }

            if state.previewIsStale {
                Label("设置已更改，请重新生成预览", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let result = state.previewResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实际大小：\(formatBytes(result.fileSizeBytes))")
                    Text("输出：\(result.configuration.maxWidth) px · \(Int(result.configuration.fps)) fps")
                    if !result.targetWasMet {
                        Text("自动压缩后仍未达到目标体积。")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if state.isPreviewing {
                ProgressView(value: state.previewProgress) {
                    Text("生成中… \(Int(state.previewProgress * 100))%")
                }
                Button(state.isCancelling ? "正在取消…" : "取消生成", role: .cancel) {
                    state.cancelProcessing()
                }
                .disabled(state.isCancelling)
            } else {
                Button(action: state.generateGIFPreview) {
                    Label(
                        state.previewURL == nil ? "生成 GIF 预览" : "重新生成预览",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.videoURL == nil || state.trimDuration <= 0 || state.isProcessing)
            }

            Text("预览和正式导出使用同一渲染流程。目标体积模式可能需要多次编码。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AnimatedGIFNSView {
        let view = AnimatedGIFNSView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.animates = true
        view.isEditable = false
        view.setURL(url)
        return view
    }

    func updateNSView(_ nsView: AnimatedGIFNSView, context: Context) {
        nsView.setURL(url)
    }
}

private final class AnimatedGIFNSView: NSImageView {
    private var representedURL: URL?

    /// 不让 GIF 的原始像素宽度撑破 SwiftUI 侧栏。
    override var intrinsicContentSize: NSSize {
        NSSize(width: 1, height: 220)
    }

    func setURL(_ url: URL) {
        guard representedURL != url else { return }
        representedURL = url
        animates = false
        image = NSImage(contentsOf: url)
        animates = true
    }
}
