import Foundation

enum VideoLoadingTests {
    static func testClearDuringLoadDoesNotRestoreOldAsset() throws {
        let video = try TestVideo.make(duration: 0.4, fps: 5)
        defer { try? FileManager.default.removeItem(at: video) }
        let state = AppState()

        state.loadVideo(video)
        state.clearVideo()
        pumpMainRunLoop(for: 0.3)

        try expect(state.videoURL == nil, "清空后不应恢复视频 URL")
        try expect(state.asset == nil, "清空后不应恢复资产")
        try expectEqual(state.duration, 0)
        try expect(state.player.currentItem == nil, "清空后不应恢复播放器内容")
    }

    private static func pumpMainRunLoop(for duration: Double) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
