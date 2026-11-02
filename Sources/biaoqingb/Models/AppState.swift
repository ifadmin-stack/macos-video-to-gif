import SwiftUI
import AVFoundation
import AppKit

/// 全局状态：当前视频、文字、选段范围、预览与导出任务。
final class AppState: ObservableObject {
    static let minimumTrimDuration = 0.2

    // 视频
    @Published var videoURL: URL?
    @Published var duration: Double = 0
    @Published var videoSize: CGSize = .zero
    @Published private(set) var asset: AVAsset?

    // 选段（秒）
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 0

    // 画面裁剪（归一化坐标，相对显示画面）
    @Published var cropEnabled = false
    @Published var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    // 文字
    @Published var captions: [Caption] = []
    @Published var selectedCaptionID: Caption.ID?

    // 导出设置
    @Published var fps: Double = 12
    @Published var maxWidth: Double = 320
    @Published var loopForever = true
    @Published var targetSizeEnabled = false
    @Published var targetSizeMB = 2.0
    @Published var playbackSpeed = 1.0
    @Published var playbackMode: GIFPlaybackMode = .normal

    // 预览与导出状态
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var lastExportedURL: URL?
    @Published private(set) var lastExportResult: GIFExportResult?
    @Published private(set) var isPreviewing = false
    @Published private(set) var previewProgress: Double = 0
    @Published private(set) var previewURL: URL?
    @Published private(set) var previewResult: GIFExportResult?
    @Published private(set) var isCancelling = false
    @Published private(set) var didCopyExportedGIF = false
    @Published var errorMessage: String?

    let player = AVPlayer()
    private let exporter = GIFExporter()
    private var activeCancellation: ExportCancellation?
    private var previewRequestedConfiguration: GIFExportConfiguration?
    private var videoLoadID: UUID?

    var trimDuration: Double { max(0, trimEnd - trimStart) }
    var isProcessing: Bool { isExporting || isPreviewing }
    var outputFrameCount: Int { makeConfiguration().frameSamples.count }

    var previewIsStale: Bool {
        guard previewURL != nil, let previewRequestedConfiguration else { return false }
        return previewRequestedConfiguration != makeConfiguration()
    }

    // MARK: - 打开视频

    func openVideoPanel() {
        guard !isProcessing else { return }
        let panel = NSOpenPanel()
        var types: [UTType] = [.movie, .video]
        types += ["mkv", "avi", "webm", "mts", "m2ts"].compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(url)
        }
    }

    func loadVideo(_ url: URL) {
        resetProject()
        player.pause()
        player.replaceCurrentItem(with: nil)

        let asset = AVURLAsset(url: url)
        let loadID = UUID()
        videoLoadID = loadID
        self.asset = asset
        self.videoURL = url

        Task {
            do {
                let duration = try await asset.load(.duration).seconds
                var size = CGSize(width: 640, height: 360)
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    let natural = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    let rotated = natural.applying(transform)
                    size = CGSize(width: abs(rotated.width), height: abs(rotated.height))
                }
                let finalSize = size
                await MainActor.run {
                    guard self.videoLoadID == loadID else { return }
                    self.duration = duration
                    self.videoSize = finalSize
                    self.trimStart = 0
                    self.trimEnd = min(duration, 10)
                    self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                }
            } catch {
                await MainActor.run {
                    guard self.videoLoadID == loadID else { return }
                    self.errorMessage = "无法读取视频：\(error.localizedDescription)"
                }
            }
        }
    }

    func clearVideo() {
        resetProject()
        player.pause()
        player.replaceCurrentItem(with: nil)
        videoURL = nil
        asset = nil
    }

    private func resetProject() {
        videoLoadID = nil
        activeCancellation?.cancel()
        activeCancellation = nil
        isExporting = false
        isPreviewing = false
        isCancelling = false
        exportProgress = 0
        previewProgress = 0
        lastExportedURL = nil
        lastExportResult = nil
        didCopyExportedGIF = false
        errorMessage = nil
        removePreview()

        duration = 0
        videoSize = .zero
        trimStart = 0
        trimEnd = 0
        cropEnabled = false
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        captions = []
        selectedCaptionID = nil
    }

    // MARK: - 文字

    func addCaption() {
        guard trimDuration > 0 else { return }
        let caption = Caption(
            text: "文字",
            start: trimStart,
            end: min(trimEnd, trimStart + 2)
        )
        captions.append(caption)
        selectedCaptionID = caption.id
    }

    func updateCaption(_ caption: Caption) {
        guard duration > 0, let index = captions.firstIndex(where: { $0.id == caption.id }) else {
            return
        }
        var updated = caption
        let minimumDuration = min(0.1, duration)
        updated.start = min(max(0, updated.start), max(0, duration - minimumDuration))
        updated.end = min(duration, max(updated.start + minimumDuration, updated.end))
        updated.fontSize = min(144, max(8, updated.fontSize))
        captions[index] = updated
    }

    func removeCaption(id: Caption.ID) {
        guard let index = captions.firstIndex(where: { $0.id == id }) else { return }
        captions.remove(at: index)
        if selectedCaptionID == id {
            selectedCaptionID = captions.first?.id
        }
    }

    // MARK: - 逐帧选段

    func nudgeTrimStart(frames: Int) {
        let delta = Double(frames) / max(1, fps)
        let latestStart = max(0, trimEnd - Self.minimumTrimDuration)
        trimStart = min(max(0, trimStart + delta), latestStart)
    }

    func nudgeTrimEnd(frames: Int) {
        let delta = Double(frames) / max(1, fps)
        let earliestEnd = min(duration, trimStart + Self.minimumTrimDuration)
        trimEnd = max(earliestEnd, min(duration, trimEnd + delta))
    }

    // MARK: - 导出 GIF

    func exportGIF() {
        guard let asset, trimDuration > 0.05, !isProcessing else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = defaultFileName()
        guard panel.runModal() == .OK, let output = panel.url else { return }

        let configuration = makeConfiguration()
        let cancellation = ExportCancellation()
        activeCancellation = cancellation
        isExporting = true
        isCancelling = false
        exportProgress = 0
        lastExportedURL = nil
        lastExportResult = nil
        didCopyExportedGIF = false

        exporter.export(
            asset: asset,
            configuration: configuration,
            output: output,
            cancellation: cancellation,
            progress: { [weak self] value in
                DispatchQueue.main.async {
                    guard self?.activeCancellation === cancellation else { return }
                    self?.exportProgress = value
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.activeCancellation === cancellation else { return }
                    self.finishActiveOperation()
                    switch result {
                    case .success(let exportResult):
                        self.lastExportedURL = exportResult.url
                        self.lastExportResult = exportResult
                        NSWorkspace.shared.activateFileViewerSelecting([exportResult.url])
                    case .failure(let error):
                        self.presentErrorIfNeeded(error, prefix: "导出失败")
                    }
                }
            }
        )
    }

    // MARK: - 真实 GIF 预览

    func generateGIFPreview() {
        guard let asset, trimDuration > 0.05, !isProcessing else { return }
        player.pause()
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("biaoqingb-preview-\(UUID().uuidString).gif")
        let configuration = makeConfiguration()
        let cancellation = ExportCancellation()
        activeCancellation = cancellation
        isPreviewing = true
        isCancelling = false
        previewProgress = 0

        exporter.export(
            asset: asset,
            configuration: configuration,
            output: output,
            cancellation: cancellation,
            progress: { [weak self] value in
                DispatchQueue.main.async {
                    guard self?.activeCancellation === cancellation else { return }
                    self?.previewProgress = value
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.activeCancellation === cancellation else { return }
                    self.finishActiveOperation()
                    switch result {
                    case .success(let exportResult):
                        self.removePreview()
                        self.previewURL = exportResult.url
                        self.previewResult = exportResult
                        self.previewRequestedConfiguration = configuration
                    case .failure(let error):
                        self.presentErrorIfNeeded(error, prefix: "预览失败")
                    }
                }
            }
        )
    }

    func cancelProcessing() {
        guard activeCancellation != nil else { return }
        isCancelling = true
        activeCancellation?.cancel()
    }

    // MARK: - 复制与分享

    func copyExportedGIF() {
        guard let url = lastExportResult?.url else { return }
        do {
            try GIFSharing.copyGIF(at: url, to: .general)
            didCopyExportedGIF = true
        } catch {
            didCopyExportedGIF = false
            errorMessage = "复制失败：\(error.localizedDescription)"
        }
    }

    private func finishActiveOperation() {
        activeCancellation = nil
        isExporting = false
        isPreviewing = false
        isCancelling = false
    }

    private func presentErrorIfNeeded(_ error: Error, prefix: String) {
        if let exportError = error as? GIFExportError, case .cancelled = exportError {
            return
        }
        errorMessage = "\(prefix)：\(error.localizedDescription)"
    }

    private func removePreview() {
        if let previewURL {
            try? FileManager.default.removeItem(at: previewURL)
        }
        previewURL = nil
        previewResult = nil
        previewRequestedConfiguration = nil
    }

    private func makeConfiguration() -> GIFExportConfiguration {
        GIFExportConfiguration(
            start: trimStart,
            end: trimEnd,
            fps: fps,
            maxWidth: Int(maxWidth),
            loopForever: loopForever,
            cropRectNormalized: cropEnabled ? cropRect : nil,
            captions: captions,
            targetBytes: targetSizeEnabled ? Int(targetSizeMB * 1_000_000) : nil,
            playbackSpeed: playbackSpeed,
            playbackMode: playbackMode
        )
    }

    private func defaultFileName() -> String {
        let base = videoURL?.deletingPathExtension().lastPathComponent ?? "sticker"
        return "\(base).gif"
    }

    // MARK: - 预览控制

    func playSelection() {
        player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600)) { [weak self] _ in
            self?.player.play()
        }
    }

    func pause() {
        player.pause()
    }
}
