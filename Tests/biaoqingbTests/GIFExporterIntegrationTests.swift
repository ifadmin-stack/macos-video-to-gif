import Foundation
import AVFoundation
import CoreVideo
import ImageIO
import AppKit

enum GIFExporterIntegrationTests {
    static func testExportsRealGIFWithExpectedFrameCount() throws {
        let video = try TestVideo.make(duration: 1, fps: 10)
        defer { try? FileManager.default.removeItem(at: video) }
        let output = temporaryOutput(name: "real-export")
        let configuration = GIFExportConfiguration(
            start: 0,
            end: 1,
            fps: 5,
            maxWidth: 96,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [Caption(text: "测试", start: 0, end: 1)],
            targetBytes: nil
        )

        let result = try export(video: video, configuration: configuration, output: output)
        defer { try? FileManager.default.removeItem(at: result.url) }

        try expect(result.fileSizeBytes > 0, "导出文件不应为空")
        try expectEqual(result.configuration.maxWidth, 96)
        let source = try unwrap(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        try expectEqual(CGImageSourceGetCount(source), 5)
    }

    static func testImpossibleTargetReturnsHonestResult() throws {
        let video = try TestVideo.make(duration: 0.4, fps: 5)
        defer { try? FileManager.default.removeItem(at: video) }
        let output = temporaryOutput(name: "small-target")
        let configuration = GIFExportConfiguration(
            start: 0,
            end: 0.4,
            fps: 5,
            maxWidth: 160,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [],
            targetBytes: 1
        )

        let result = try export(video: video, configuration: configuration, output: output)
        defer { try? FileManager.default.removeItem(at: result.url) }

        try expect(!result.targetWasMet, "1 字节目标不应被报告为达标")
        try expectEqual(result.fileSizeBytes, try fileSize(of: result.url))
        try expectEqual(result.configuration.maxWidth, GIFExportConfiguration.minimumWidth)
        try expectEqual(result.configuration.fps, GIFExportConfiguration.minimumFPS)
    }

    static func testCancelledExportLeavesNoOutput() throws {
        let video = try TestVideo.make(duration: 0.4, fps: 5)
        defer { try? FileManager.default.removeItem(at: video) }
        let output = temporaryOutput(name: "cancelled-export")
        let configuration = GIFExportConfiguration(
            start: 0,
            end: 0.4,
            fps: 5,
            maxWidth: 160,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [],
            targetBytes: nil
        )
        let cancellation = ExportCancellation()
        cancellation.cancel()

        let semaphore = DispatchSemaphore(value: 0)
        var completion: Result<GIFExportResult, Error>?
        GIFExporter().export(
            asset: AVURLAsset(url: video),
            configuration: configuration,
            output: output,
            cancellation: cancellation,
            progress: { _ in },
            completion: {
                completion = $0
                semaphore.signal()
            }
        )

        try expect(semaphore.wait(timeout: .now() + 10) == .success, "取消任务不应卡住")
        guard case .failure(let error)? = completion,
              let exportError = error as? GIFExportError,
              case .cancelled = exportError else {
            throw TestFailure(description: "取消任务应返回 cancelled，实际 \(String(describing: completion))")
        }
        try expect(!FileManager.default.fileExists(atPath: output.path), "取消后不应留下输出文件")
    }

    static func testFractionalDurationIncludesFinalFrame() throws {
        let video = try TestVideo.make(duration: 0.4, fps: 5)
        defer { try? FileManager.default.removeItem(at: video) }
        let output = temporaryOutput(name: "fractional-duration")
        let configuration = GIFExportConfiguration(
            start: 0,
            end: 0.3,
            fps: 5,
            maxWidth: 96,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [Caption(text: "末帧", start: 0.2, end: 0.3)],
            targetBytes: nil
        )

        let result = try export(video: video, configuration: configuration, output: output)
        defer { try? FileManager.default.removeItem(at: result.url) }

        let source = try unwrap(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        try expectEqual(CGImageSourceGetCount(source), 2)
    }

    static func testPlaybackEffectsAreEncodedIntoGIF() throws {
        let video = try TestVideo.make(duration: 0.6, fps: 5)
        defer { try? FileManager.default.removeItem(at: video) }

        let reversedOutput = temporaryOutput(name: "reverse-speed")
        var reversedConfiguration = GIFExportConfiguration(
            start: 0,
            end: 0.6,
            fps: 5,
            maxWidth: 96,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [],
            targetBytes: nil
        )
        reversedConfiguration.playbackMode = .reverse
        reversedConfiguration.playbackSpeed = 2
        let reversed = try export(
            video: video,
            configuration: reversedConfiguration,
            output: reversedOutput
        )
        defer { try? FileManager.default.removeItem(at: reversed.url) }
        let reversedSource = try unwrap(CGImageSourceCreateWithURL(reversed.url as CFURL, nil))
        try expectEqual(CGImageSourceGetCount(reversedSource), 3)
        try expectClose(try frameDelay(of: reversedSource, at: 0), 0.1)

        let boomerangOutput = temporaryOutput(name: "boomerang")
        var boomerangConfiguration = reversedConfiguration
        boomerangConfiguration.playbackMode = .boomerang
        boomerangConfiguration.playbackSpeed = 1
        let boomerang = try export(
            video: video,
            configuration: boomerangConfiguration,
            output: boomerangOutput
        )
        defer { try? FileManager.default.removeItem(at: boomerang.url) }
        let boomerangSource = try unwrap(CGImageSourceCreateWithURL(boomerang.url as CFURL, nil))
        try expectEqual(CGImageSourceGetCount(boomerangSource), 4)
        try expectClose(try frameDelay(of: boomerangSource, at: 0), 0.2)
    }

    private static func export(
        video: URL,
        configuration: GIFExportConfiguration,
        output: URL
    ) throws -> GIFExportResult {
        let semaphore = DispatchSemaphore(value: 0)
        var completion: Result<GIFExportResult, Error>?
        GIFExporter().export(
            asset: AVURLAsset(url: video),
            configuration: configuration,
            output: output,
            cancellation: ExportCancellation(),
            progress: { _ in },
            completion: {
                completion = $0
                semaphore.signal()
            }
        )
        try expect(semaphore.wait(timeout: .now() + 20) == .success, "导出超时")
        switch completion {
        case .success(let result): return result
        case .failure(let error): throw error
        case nil: throw TestFailure(description: "导出没有回调")
        }
    }

    private static func temporaryOutput(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("biaoqingb-test-\(name)-\(UUID().uuidString).gif")
    }

    private static func fileSize(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try unwrap(attributes[.size] as? NSNumber).intValue
    }

    private static func frameDelay(of source: CGImageSource, at index: Int) throws -> Double {
        let properties = try unwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any])
        let gifProperties = try unwrap(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
        return try unwrap(gifProperties[kCGImagePropertyGIFDelayTime as String] as? NSNumber).doubleValue
    }
}

enum TestVideo {
    static func make(duration: Double, fps: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("biaoqingb-test-video-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = 96
        let height = 96
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        try expect(writer.canAdd(input), "无法创建测试视频输入")
        writer.add(input)
        try expect(writer.startWriting(), "无法开始写入测试视频：\(writer.error?.localizedDescription ?? "未知错误")")
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(duration * Double(fps)))
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed || writer.status == .cancelled {
                    throw writer.error ?? TestFailure(description: "测试视频写入失败")
                }
                Thread.sleep(forTimeInterval: 0.005)
            }
            let buffer = try makeFrame(width: width, height: height, frame: frame, adaptor: adaptor)
            let time = CMTime(value: Int64(frame), timescale: CMTimeScale(fps))
            try expect(adaptor.append(buffer, withPresentationTime: time), "无法追加测试视频帧")
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        try expect(semaphore.wait(timeout: .now() + 10) == .success, "测试视频写入超时")
        try expect(writer.status == .completed, "测试视频未完成：\(writer.error?.localizedDescription ?? "未知错误")")
        return url
    }

    private static func makeFrame(
        width: Int,
        height: Int,
        frame: Int,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        let pool = try unwrap(adaptor.pixelBufferPool)
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
        let buffer = try unwrap(optionalBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        let validContext = try unwrap(context)
        validContext.setFillColor(NSColor(calibratedWhite: 0.9, alpha: 1).cgColor)
        validContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        validContext.setFillColor(NSColor.systemBlue.cgColor)
        validContext.fill(CGRect(x: frame * 3 % width, y: 12, width: 24, height: 48))
        validContext.setFillColor(NSColor.systemRed.cgColor)
        validContext.fill(CGRect(x: 12, y: 48, width: 48, height: 24))
        return buffer
    }
}
