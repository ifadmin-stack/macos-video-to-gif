import Foundation
import UniformTypeIdentifiers

/// 判断文件是否为可导入的视频格式
enum VideoFormat {
    /// 常见可播放扩展名（AVFoundation 支持的容器）
    private static let supportedExtensions: Set<String> = [
        "mp4", "mov", "m4v", "m2ts", "mts", "3gp", "webm", "mkv", "avi"
    ]

    static func isSupported(_ url: URL) -> Bool {
        // 优先看内容类型是否属于视频
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .movie) || type.conforms(to: .video) {
            return true
        }
        // 兜底：按扩展名白名单（mkv/avi 等系统未必注册 UTI）
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
