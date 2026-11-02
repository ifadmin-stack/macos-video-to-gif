import Foundation
import CoreGraphics

struct GIFExportConfiguration: Equatable {
    static let minimumWidth = 120
    static let minimumFPS = 5.0

    var start: Double
    var end: Double
    var fps: Double
    var maxWidth: Int
    var loopForever: Bool
    var cropRectNormalized: CGRect?
    var captions: [Caption]
    var targetBytes: Int?
    var playbackSpeed: Double = 1.0
    var playbackMode: GIFPlaybackMode = .normal

    var frameSamples: [GIFFrameSample] {
        GIFTimeline.samples(start: start, end: end, fps: fps, speed: playbackSpeed, mode: playbackMode)
    }

    var outputFrameDelay: Double? {
        GIFTimeline.frameDelay(fps: fps, speed: playbackSpeed)
    }

    /// 根据上一版真实体积计算下一版参数，最多降低质量，不提高用户原始设置。
    func reducedForTarget(actualBytes: Int) -> Self? {
        guard let targetBytes, targetBytes > 0, actualBytes > targetBytes else { return nil }

        let ratio = Double(targetBytes) / Double(actualBytes)
        let scale = sqrt(ratio)
        var next = self

        if fps > Self.minimumFPS, actualBytes >= targetBytes * 2 || maxWidth <= Self.minimumWidth {
            let fpsScale = max(0.5, scale)
            next.fps = max(Self.minimumFPS, (fps * fpsScale).rounded(.down))
        }

        if maxWidth > Self.minimumWidth {
            let widthScale = min(0.9, max(0.35, scale))
            let candidate = Int((Double(maxWidth) * widthScale).rounded(.down))
            let stepped = max(Self.minimumWidth, candidate / 20 * 20)
            next.maxWidth = max(Self.minimumWidth, min(maxWidth - 20, stepped))
        }

        return next == self ? nil : next
    }
}

struct GIFExportResult {
    let url: URL
    let fileSizeBytes: Int
    let configuration: GIFExportConfiguration

    var targetWasMet: Bool {
        guard let targetBytes = configuration.targetBytes else { return true }
        return fileSizeBytes <= targetBytes
    }
}

final class ExportCancellation {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    /// 在同一临界区内读取取消状态并提交结果，避免检查与提交之间发生竞态。
    func withStateLock<T>(_ body: (Bool) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(cancelled)
    }
}
