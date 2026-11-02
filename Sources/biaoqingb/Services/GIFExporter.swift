import Foundation
import AVFoundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

enum GIFExportError: LocalizedError {
    case cancelled
    case noFrames
    case cannotCreateDestination
    case cannotRenderFrame
    case cannotMeasureOutput
    case invalidConfiguration
    case frameGenerationFailed(time: Double, message: String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "已取消"
        case .noFrames: return "所选时间段内没有可取到的帧"
        case .cannotCreateDestination: return "无法创建 GIF 文件"
        case .cannotRenderFrame: return "无法渲染 GIF 画面"
        case .cannotMeasureOutput: return "无法读取 GIF 文件大小"
        case .invalidConfiguration: return "导出参数无效，请检查选段、帧率和播放速度"
        case .frameGenerationFailed(let time, let message):
            return String(format: "无法读取 %.2f 秒处的画面：%@", time, message)
        }
    }
}

private extension ExportCancellation {
    func check() throws {
        if isCancelled { throw GIFExportError.cancelled }
    }
}

/// 抽帧 → 裁剪 → 缩放/文字 → ImageIO 编码，并按真实文件大小控制目标体积。
final class GIFExporter {
    private let maximumAttempts = 5

    func export(
        asset: AVAsset,
        configuration: GIFExportConfiguration,
        output: URL,
        cancellation: ExportCancellation,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<GIFExportResult, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.performExport(
                    asset: asset,
                    initialConfiguration: configuration,
                    output: output,
                    cancellation: cancellation,
                    progress: progress
                )
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func performExport(
        asset: AVAsset,
        initialConfiguration: GIFExportConfiguration,
        output: URL,
        cancellation: ExportCancellation,
        progress: @escaping (Double) -> Void
    ) throws -> GIFExportResult {
        var configuration = initialConfiguration
        var workingURL: URL?

        do {
            for attempt in 0..<maximumAttempts {
                try cancellation.check()
                let candidate = temporaryURL(for: output)
                workingURL = candidate
                let attemptCount = configuration.targetBytes == nil ? 1 : maximumAttempts

                try encode(
                    asset: asset,
                    configuration: configuration,
                    output: candidate,
                    cancellation: cancellation,
                    progress: { value in
                        let overall = (Double(attempt) + value * 0.95) / Double(attemptCount)
                        progress(min(0.95, overall))
                    }
                )
                try cancellation.check()
                let fileSize = try Self.fileSize(of: candidate)

                let shouldReturn = configuration.targetBytes.map { fileSize <= $0 } ?? true
                if shouldReturn || attempt == maximumAttempts - 1 {
                    let result = try commit(
                        candidate: candidate,
                        output: output,
                        configuration: configuration,
                        fileSize: fileSize,
                        cancellation: cancellation,
                        progress: progress
                    )
                    workingURL = nil
                    return result
                }

                guard let reduced = configuration.reducedForTarget(actualBytes: fileSize) else {
                    let result = try commit(
                        candidate: candidate,
                        output: output,
                        configuration: configuration,
                        fileSize: fileSize,
                        cancellation: cancellation,
                        progress: progress
                    )
                    workingURL = nil
                    return result
                }

                try Self.removeFileIfPresent(at: candidate)
                workingURL = nil
                configuration = reduced
            }

            throw GIFExportError.cannotCreateDestination
        } catch {
            if let workingURL {
                try? Self.removeFileIfPresent(at: workingURL)
            }
            throw error
        }
    }

    private func commit(
        candidate: URL,
        output: URL,
        configuration: GIFExportConfiguration,
        fileSize: Int,
        cancellation: ExportCancellation,
        progress: @escaping (Double) -> Void
    ) throws -> GIFExportResult {
        let result = try cancellation.withStateLock { cancelled in
            if cancelled { throw GIFExportError.cancelled }
            try Self.moveFinishedFile(from: candidate, to: output)
            return GIFExportResult(
                url: output,
                fileSizeBytes: fileSize,
                configuration: configuration
            )
        }
        progress(1)
        return result
    }

    private func encode(
        asset: AVAsset,
        configuration: GIFExportConfiguration,
        output: URL,
        cancellation: ExportCancellation,
        progress: @escaping (Double) -> Void
    ) throws {
        let samples = configuration.frameSamples
        guard let frameDelay = configuration.outputFrameDelay, !samples.isEmpty else {
            throw GIFExportError.invalidConfiguration
        }
        let sourceFrameDelay = 1.0 / configuration.fps
        let frameCount = samples.count

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cropScale = configuration.cropRectNormalized.map { min($0.width, $0.height) } ?? 1.0
        let sampleSide = min(
            4096,
            Int(CGFloat(configuration.maxWidth * 2) / max(0.1, cropScale))
        )
        generator.maximumSize = CGSize(width: sampleSide, height: sampleSide)
        generator.requestedTimeToleranceBefore = CMTime(
            seconds: sourceFrameDelay / 2,
            preferredTimescale: 600
        )
        generator.requestedTimeToleranceAfter = CMTime(
            seconds: sourceFrameDelay / 2,
            preferredTimescale: 600
        )

        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw GIFExportError.cannotCreateDestination
        }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: configuration.loopForever ? 0 : 1
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFHasGlobalColorMap as String: true
            ]
        ]

        var written = 0
        for (index, sample) in samples.enumerated() {
            try cancellation.check()
            let time = sample.sourceTime
            try autoreleasepool {
                let cgImage: CGImage
                do {
                    cgImage = try generator.copyCGImage(
                        at: CMTime(seconds: time, preferredTimescale: 600),
                        actualTime: nil
                    )
                } catch {
                    throw GIFExportError.frameGenerationFailed(
                        time: time,
                        message: error.localizedDescription
                    )
                }

                var image = cgImage
                if let crop = configuration.cropRectNormalized {
                    let rect = CGRect(
                        x: crop.minX * CGFloat(image.width),
                        y: crop.minY * CGFloat(image.height),
                        width: crop.width * CGFloat(image.width),
                        height: crop.height * CGFloat(image.height)
                    ).integral
                    guard let cropped = image.cropping(to: rect) else {
                        throw GIFExportError.cannotRenderFrame
                    }
                    image = cropped
                }

                guard let rendered = GIFRenderer.render(
                    image: image,
                    maxWidth: configuration.maxWidth,
                    captions: configuration.captions,
                    time: time
                ) else {
                    throw GIFExportError.cannotRenderFrame
                }
                CGImageDestinationAddImage(destination, rendered, frameProperties as CFDictionary)
                written += 1
            }
            progress(Double(index + 1) / Double(frameCount))
        }

        guard written > 0 else { throw GIFExportError.noFrames }
        try cancellation.check()
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExportError.cannotCreateDestination
        }
    }

    private func temporaryURL(for output: URL) -> URL {
        output.deletingLastPathComponent().appendingPathComponent(
            ".\(output.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).gif"
        )
    }

    private static func fileSize(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw GIFExportError.cannotMeasureOutput
        }
        return size.intValue
    }

    private static func moveFinishedFile(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: source)
        } else {
            try fileManager.moveItem(at: source, to: destination)
        }
    }

    private static func removeFileIfPresent(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
