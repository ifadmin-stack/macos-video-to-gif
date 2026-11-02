import Foundation
import CoreGraphics
import AppKit

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(
    _ condition: @autoclosure () throws -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard try condition() else {
        throw TestFailure(description: "\(file):\(line): \(message)")
    }
}

func expectEqual<T: Equatable>(
    _ actual: @autoclosure () throws -> T,
    _ expected: @autoclosure () throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let actualValue = try actual()
    let expectedValue = try expected()
    try expect(actualValue == expectedValue, "期望 \(expectedValue)，实际 \(actualValue)", file: file, line: line)
}

func expectClose(
    _ actual: Double,
    _ expected: Double,
    accuracy: Double = 0.000_001,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try expect(
        abs(actual - expected) <= accuracy,
        "期望 \(expected)（误差 \(accuracy)），实际 \(actual)",
        file: file,
        line: line
    )
}

func unwrap<T>(
    _ value: @autoclosure () throws -> T?,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    guard let value = try value() else {
        throw TestFailure(description: "\(file):\(line):  unexpectedly nil")
    }
    return value
}

enum CaptionTests {
    static func testCaptionUsesHalfOpenTimeRange() throws {
        let caption = Caption(text: "测试", start: 1, end: 2)

        try expect(!caption.isActive(at: 0.99), "开始时间前不应显示")
        try expect(caption.isActive(at: 1), "开始时间应显示")
        try expect(caption.isActive(at: 1.99), "结束时间前应显示")
        try expect(!caption.isActive(at: 2), "结束时间不应显示")
    }

    static func testBlankCaptionIsNeverActive() throws {
        let caption = Caption(text: "  \n", start: 0, end: 2)

        try expect(!caption.isActive(at: 1), "空白文字不应绘制")
    }

    static func testRendererDrawsOnlyActiveCaptions() throws {
        let image = try makeSolidImage(width: 160, height: 90)
        let caption = Caption(text: "TEST", start: 0, end: 1, fontSize: 28)

        let plain = try unwrap(GIFRenderer.render(
            image: image, maxWidth: 160, captions: [], time: 0.5
        ))
        let inactive = try unwrap(GIFRenderer.render(
            image: image, maxWidth: 160, captions: [caption], time: 1.5
        ))
        let active = try unwrap(GIFRenderer.render(
            image: image, maxWidth: 160, captions: [caption], time: 0.5
        ))

        try expectEqual(try rgbaData(from: plain), try rgbaData(from: inactive))
        try expect(try rgbaData(from: plain) != rgbaData(from: active), "有效文字应改变输出像素")
    }

    private static func makeSolidImage(width: Int, height: Int) throws -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let validContext = try unwrap(context)
        validContext.setFillColor(NSColor.white.cgColor)
        validContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try unwrap(validContext.makeImage())
    }

    private static func rgbaData(from image: CGImage) throws -> Data {
        var data = Data(count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return }
            let context = CGContext(
                data: address,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }
}

enum ExportCompressionTests {
    static func testLargeResultReducesWidthAndFrameRate() throws {
        let configuration = makeConfiguration(fps: 24, maxWidth: 640)
        let reduced = try unwrap(configuration.reducedForTarget(actualBytes: 4_000_000))

        try expectEqual(reduced.maxWidth, 320)
        try expectEqual(reduced.fps, 12)
    }

    static func testReductionNeverCrossesQualityLimits() throws {
        let configuration = makeConfiguration(fps: 6, maxWidth: 140)
        let reduced = try unwrap(configuration.reducedForTarget(actualBytes: 50_000_000))

        try expectEqual(reduced.maxWidth, GIFExportConfiguration.minimumWidth)
        try expectEqual(reduced.fps, GIFExportConfiguration.minimumFPS)
    }

    static func testMinimumConfigurationCannotReduceFurther() throws {
        let configuration = makeConfiguration(
            fps: GIFExportConfiguration.minimumFPS,
            maxWidth: GIFExportConfiguration.minimumWidth
        )

        try expect(configuration.reducedForTarget(actualBytes: 50_000_000) == nil, "最低参数不应继续降级")
    }

    static func testMinimumWidthStillReducesFrameRate() throws {
        let configuration = makeConfiguration(fps: 12, maxWidth: GIFExportConfiguration.minimumWidth)
        let reduced = try unwrap(configuration.reducedForTarget(actualBytes: 1_500_000))

        try expectEqual(reduced.maxWidth, GIFExportConfiguration.minimumWidth)
        try expect(reduced.fps < configuration.fps, "宽度最低时仍应继续降低帧率")
        try expect(reduced.fps >= GIFExportConfiguration.minimumFPS, "帧率不应低于下限")
    }

    private static func makeConfiguration(fps: Double, maxWidth: Int) -> GIFExportConfiguration {
        GIFExportConfiguration(
            start: 0,
            end: 2,
            fps: fps,
            maxWidth: maxWidth,
            loopForever: true,
            cropRectNormalized: nil,
            captions: [],
            targetBytes: 1_000_000
        )
    }
}

enum ExportCancellationTests {
    static func testCancellationIsIdempotent() throws {
        let cancellation = ExportCancellation()

        try expect(!cancellation.isCancelled, "初始状态不应取消")
        cancellation.cancel()
        cancellation.cancel()
        try expect(cancellation.isCancelled, "取消后应记录状态")
    }

    static func testCancellationAndCommitAreSerialized() throws {
        let cancellation = ExportCancellation()
        let commitStarted = DispatchSemaphore(value: 0)
        let allowCommit = DispatchSemaphore(value: 0)
        let cancelReturned = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "ExportCancellationTests", attributes: .concurrent)

        queue.async {
            cancellation.withStateLock { _ in
                commitStarted.signal()
                allowCommit.wait()
            }
        }
        try expect(commitStarted.wait(timeout: .now() + 1) == .success, "提交未开始")

        queue.async {
            cancellation.cancel()
            cancelReturned.signal()
        }
        try expect(cancelReturned.wait(timeout: .now() + 0.05) == .timedOut, "取消不应穿过正在提交的任务")

        allowCommit.signal()
        try expect(cancelReturned.wait(timeout: .now() + 1) == .success, "提交后取消应能完成")
        try expect(cancellation.isCancelled, "取消状态应被保留")
    }
}

enum TrimNudgingTests {
    static func testNudgingUsesCurrentFrameDuration() throws {
        let state = AppState()
        state.duration = 3
        state.trimStart = 0.5
        state.trimEnd = 2
        state.fps = 10

        state.nudgeTrimStart(frames: 1)
        state.nudgeTrimEnd(frames: -1)

        try expectClose(state.trimStart, 0.6)
        try expectClose(state.trimEnd, 1.9)
    }

    static func testNudgingCannotCrossSelectionBounds() throws {
        let state = AppState()
        state.duration = 1
        state.trimStart = 0.2
        state.trimEnd = 0.4
        state.fps = 10

        state.nudgeTrimStart(frames: 100)
        try expectClose(state.trimStart, 0.2)

        state.nudgeTrimStart(frames: -100)
        try expectClose(state.trimStart, 0)

        state.nudgeTrimEnd(frames: 100)
        try expectClose(state.trimEnd, 1)

        state.nudgeTrimEnd(frames: -100)
        try expectClose(state.trimEnd, 0.2)
    }
}
