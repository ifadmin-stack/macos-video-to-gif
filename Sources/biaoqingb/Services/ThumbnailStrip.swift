import AVFoundation
import AppKit

/// 为时间轴生成等间隔缩略图
final class ThumbnailStrip {

    static func generate(
        asset: AVAsset,
        count: Int = 12,
        height: CGFloat = 48
    ) async -> [NSImage] {
        guard let duration = try? await asset.load(.duration).seconds, duration > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: height * 3, height: height * 2)
        generator.requestedTimeToleranceBefore = .init(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = .init(seconds: 0.5, preferredTimescale: 600)

        var images: [NSImage] = []
        for i in 0..<count {
            let t = duration * Double(i) / Double(max(1, count - 1))
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(NSImage(cgImage: cg, size: .zero))
            }
        }
        return images
    }
}
