import SwiftUI

/// 视频画面上的裁剪框：内部拖动移动位置，右下角手柄缩放。
/// 坐标全部用归一化（0~1，相对视频显示画面，左上原点）存储在 AppState.cropRect。
struct CropOverlay: View {
    @EnvironmentObject var state: AppState
    @State private var dragStartRect: CGRect?

    private let minSize: CGFloat = 0.08 // 最小裁剪边长（归一化）
    private let handleSize: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let fit = Self.fitRect(container: geo.size, video: state.videoSize)
            if fit.width > 0 {
                let rect = cropRectInView(fit: fit)

                // 裁剪区外压暗（even-odd 挖洞）
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(rect)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                // 裁剪框边框（可拖动移动）
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Color.clear.contentShape(Rectangle()))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(moveGesture(fit: fit))

                // 四角参考点（仅视觉）
                ForEach(0..<4, id: \.self) { i in
                    let corner = corners(of: rect)[i]
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .position(corner)
                        .allowsHitTesting(false)
                }

                // 右下角缩放手柄
                Circle()
                    .fill(Color.accentColor)
                    .overlay(Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white))
                    .frame(width: handleSize, height: handleSize)
                    .position(x: rect.maxX, y: rect.maxY)
                    .gesture(resizeGesture(fit: fit))

                // 尺寸提示
                Text(cropSizeText)
                    .font(.caption2)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .position(x: rect.midX, y: max(12, rect.minY - 12))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 手势

    private func moveGesture(fit: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = state.cropRect }
                guard let start = dragStartRect else { return }
                let dx = value.translation.width / fit.width
                let dy = value.translation.height / fit.height
                var r = start
                r.origin.x = (start.minX + dx).clamped(to: 0...(1 - start.width))
                r.origin.y = (start.minY + dy).clamped(to: 0...(1 - start.height))
                state.cropRect = r
            }
            .onEnded { _ in dragStartRect = nil }
    }

    private func resizeGesture(fit: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = state.cropRect }
                guard let start = dragStartRect else { return }
                let dw = value.translation.width / fit.width
                let dh = value.translation.height / fit.height
                var r = start
                r.size.width = (start.width + dw).clamped(to: minSize...(1 - start.minX))
                r.size.height = (start.height + dh).clamped(to: minSize...(1 - start.minY))
                state.cropRect = r
            }
            .onEnded { _ in dragStartRect = nil }
    }

    // MARK: - 坐标换算

    /// 视频画面在容器中的 aspect-fit 位置（播放器是 resizeAspect，居中）
    static func fitRect(container: CGSize, video: CGSize) -> CGRect {
        guard video.width > 0, video.height > 0 else { return .zero }
        let scale = min(container.width / video.width, container.height / video.height)
        let size = CGSize(width: video.width * scale, height: video.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func cropRectInView(fit: CGRect) -> CGRect {
        let c = state.cropRect
        return CGRect(x: fit.minX + c.minX * fit.width,
                      y: fit.minY + c.minY * fit.height,
                      width: c.width * fit.width,
                      height: c.height * fit.height)
    }

    private func corners(of rect: CGRect) -> [CGPoint] {
        [rect.origin,
         CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.minX, y: rect.maxY),
         CGPoint(x: rect.maxX, y: rect.maxY)]
    }

    private var cropSizeText: String {
        let w = Int(state.cropRect.width * state.videoSize.width)
        let h = Int(state.cropRect.height * state.videoSize.height)
        return "\(w)×\(h)"
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
