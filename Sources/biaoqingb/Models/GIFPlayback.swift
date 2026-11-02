import Foundation

enum GIFPlaybackMode: String, CaseIterable, Identifiable {
    case normal
    case reverse
    case boomerang

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "正常"
        case .reverse: return "倒放"
        case .boomerang: return "来回"
        }
    }
}

struct GIFFrameSample: Equatable {
    let sourceTime: Double
}

/// 原视频采样时间轴；播放速度只影响输出帧延迟，不影响采样顺序。
enum GIFTimeline {
    private static let minimumGIFDelay = 0.02

    static func samples(
        start: Double,
        end: Double,
        fps: Double,
        mode: GIFPlaybackMode
    ) -> [GIFFrameSample] {
        samples(start: start, end: end, fps: fps, speed: 1, mode: mode)
    }

    static func samples(
        start: Double,
        end: Double,
        fps: Double,
        speed: Double,
        mode: GIFPlaybackMode
    ) -> [GIFFrameSample] {
        let duration = end - start
        guard start.isFinite, end.isFinite, duration.isFinite, duration > 0,
              let outputDelay = frameDelay(fps: fps, speed: speed) else {
            return []
        }
        let sourceInterval = outputDelay * speed
        guard sourceInterval.isFinite, sourceInterval > 0 else { return [] }

        let exactCount = duration / sourceInterval
        guard exactCount.isFinite, exactCount > 0, exactCount < Double(Int.max) else { return [] }
        let nearestInteger = exactCount.rounded()
        let normalizedCount = abs(exactCount - nearestInteger) < 1e-9 ? nearestInteger : exactCount
        guard normalizedCount < Double(Int.max) else { return [] }
        let frameCount = max(1, Int(ceil(normalizedCount)))
        let forward = (0..<frameCount).map {
            GIFFrameSample(sourceTime: start + Double($0) * sourceInterval)
        }

        switch mode {
        case .normal:
            return forward
        case .reverse:
            return Array(forward.reversed())
        case .boomerang:
            guard forward.count > 2 else { return forward }
            return forward + Array(forward.dropFirst().dropLast().reversed())
        }
    }

    static func frameDelay(fps: Double, speed: Double) -> Double? {
        guard fps.isFinite, speed.isFinite, fps > 0, speed > 0 else { return nil }
        let requestedDelay = 1.0 / (fps * speed)
        guard requestedDelay.isFinite, requestedDelay > 0 else { return nil }
        return max(minimumGIFDelay, requestedDelay)
    }
}
