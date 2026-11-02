import SwiftUI
import AVFoundation

/// 时间轴：缩略图条 + 双滑块选段
struct TrimTimelineView: View {
    @EnvironmentObject var state: AppState
    @State private var thumbnails: [NSImage] = []

    private let stripHeight: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    thumbnailStrip(width: width)
                    selectionMask(width: width, left: true)
                    selectionMask(width: width, left: false)
                    selectionBorder(width: width)
                    handle(width: width, isStart: true)
                    handle(width: width, isStart: false)
                }
            }
            .frame(height: stripHeight)

            HStack {
                Text("开始 \(formatTime(state.trimStart))")
                Spacer()
                Text("时长 \(formatTime(state.trimDuration))")
                    .foregroundColor(state.trimDuration > 10 ? .red : .secondary)
                Spacer()
                Text("结束 \(formatTime(state.trimEnd))")
            }
            .font(.caption)
            .monospacedDigit()

            HStack(spacing: 10) {
                Text("逐帧调整")
                    .foregroundColor(.secondary)
                Spacer()
                Text("开始")
                frameButton(systemImage: "minus", help: "开始提前 1 帧") {
                    state.nudgeTrimStart(frames: -1)
                }
                frameButton(systemImage: "plus", help: "开始延后 1 帧") {
                    state.nudgeTrimStart(frames: 1)
                }
                Spacer()
                Text("结束")
                frameButton(systemImage: "minus", help: "结束提前 1 帧") {
                    state.nudgeTrimEnd(frames: -1)
                }
                frameButton(systemImage: "plus", help: "结束延后 1 帧") {
                    state.nudgeTrimEnd(frames: 1)
                }
            }
            .font(.caption2)
        }
        .disabled(state.isProcessing)
        .task(id: state.videoURL) {
            guard let asset = state.asset else { thumbnails = []; return }
            thumbnails = await ThumbnailStrip.generate(asset: asset)
        }
    }

    private func thumbnailStrip(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(thumbnails.indices, id: \.self) { i in
                Image(nsImage: thumbnails[i])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width / CGFloat(max(1, thumbnails.count)),
                           height: stripHeight)
                    .clipped()
            }
        }
        .frame(width: width, height: stripHeight)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }

    private func selectionMask(width: CGFloat, left: Bool) -> some View {
        let maskWidth = left ? startX(width) : width - endX(width)
        return Color.black.opacity(0.55)
            .frame(width: max(0, maskWidth), height: stripHeight)
            .offset(x: left ? 0 : endX(width))
            .allowsHitTesting(false)
    }

    private func selectionBorder(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: selectionWidth(width), height: stripHeight)
            .offset(x: startX(width))
            .allowsHitTesting(false)
    }

    private func handle(width: CGFloat, isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor)
            .frame(width: 14, height: stripHeight)
            .overlay(Image(systemName: isStart ? "chevron.left" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white))
            .offset(x: (isStart ? startX(width) : endX(width)) - 7)
            .gesture(
                DragGesture().onChanged { value in
                    let ratio = max(0, min(1, value.location.x / width))
                    let seconds = Double(ratio) * state.duration
                    if isStart {
                        state.trimStart = min(seconds, state.trimEnd - AppState.minimumTrimDuration)
                    } else {
                        state.trimEnd = max(seconds, state.trimStart + AppState.minimumTrimDuration)
                    }
                }
            )
    }

    private func frameButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
        }
        .controlSize(.small)
        .help(help)
        .accessibilityLabel(help)
    }

    private func startX(_ width: CGFloat) -> CGFloat {
        guard state.duration > 0 else { return 0 }
        return CGFloat(state.trimStart / state.duration) * width
    }

    private func endX(_ width: CGFloat) -> CGFloat {
        guard state.duration > 0 else { return width }
        return CGFloat(state.trimEnd / state.duration) * width
    }

    private func selectionWidth(_ width: CGFloat) -> CGFloat {
        max(0, endX(width) - startX(width))
    }

    private func formatTime(_ t: Double) -> String {
        String(format: "%02d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }
}
