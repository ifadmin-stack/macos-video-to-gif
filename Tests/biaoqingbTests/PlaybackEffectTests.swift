import Foundation

enum PlaybackEffectTests {
    static func testReverseUsesForwardSamplesInReverseOrder() throws {
        let samples = GIFTimeline.samples(start: 1, end: 1.6, fps: 5, mode: .reverse)

        try expectEqual(samples.count, 3)
        try expectClose(samples[0].sourceTime, 1.4)
        try expectClose(samples[1].sourceTime, 1.2)
        try expectClose(samples[2].sourceTime, 1.0)
    }

    static func testBoomerangDoesNotDuplicateLoopEndpoints() throws {
        let samples = GIFTimeline.samples(start: 0, end: 0.6, fps: 5, mode: .boomerang)

        try expectEqual(samples.map(\.sourceTime), [0, 0.2, 0.4, 0.2])
    }

    static func testSingleFrameBoomerangRemainsSingleFrame() throws {
        let samples = GIFTimeline.samples(start: 0, end: 0.1, fps: 5, mode: .boomerang)

        try expectEqual(samples.count, 1)
    }

    static func testSpeedChangesDelayButNotSourceSampleTimes() throws {
        let fast = GIFTimeline.frameDelay(fps: 10, speed: 2)
        let slow = GIFTimeline.frameDelay(fps: 10, speed: 0.5)
        let normalSamples = GIFTimeline.samples(start: 0, end: 0.4, fps: 10, mode: .normal)
        let fastSamples = GIFTimeline.samples(start: 0, end: 0.4, fps: 10, mode: .normal)

        try expectClose(try unwrap(fast), 0.05)
        try expectClose(try unwrap(slow), 0.2)
        try expectEqual(normalSamples, fastSamples)
        try expect(GIFTimeline.frameDelay(fps: 10, speed: 0) == nil, "非法速度不应生成帧延迟")
    }

    static func testExtremeValuesAreRejectedWithoutOverflow() throws {
        let samples = GIFTimeline.samples(
            start: 0,
            end: Double.greatestFiniteMagnitude,
            fps: Double.greatestFiniteMagnitude,
            mode: .normal
        )

        try expect(samples.isEmpty, "溢出输入不应生成帧")
        try expect(
            GIFTimeline.frameDelay(fps: Double.greatestFiniteMagnitude, speed: 2) == nil,
            "溢出的帧延迟应被拒绝"
        )
        try expect(
            GIFTimeline.frameDelay(fps: Double.leastNonzeroMagnitude, speed: 0.5) == nil,
            "下溢的帧延迟应被拒绝"
        )
    }

    static func testHighRatePlaybackDropsSamplesInsteadOfUsingSub20msDelay() throws {
        let samples = GIFTimeline.samples(start: 0, end: 1, fps: 24, speed: 3, mode: .normal)
        let delay = try unwrap(GIFTimeline.frameDelay(fps: 24, speed: 3))

        try expectClose(delay, 0.02)
        try expectEqual(samples.count, 17)
        try expectClose(samples[1].sourceTime, 0.06)
    }
}
