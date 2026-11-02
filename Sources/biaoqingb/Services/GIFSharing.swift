import Foundation
import AppKit
import UniformTypeIdentifiers

enum GIFSharingError: LocalizedError {
    case cannotReadFile(String)
    case pasteboardRejected
    case pasteboardRestoreFailed

    var errorDescription: String? {
        switch self {
        case .cannotReadFile(let message): return "无法读取 GIF 文件：\(message)"
        case .pasteboardRejected: return "系统剪贴板未接受 GIF"
        case .pasteboardRestoreFailed: return "剪贴板写入失败，且无法恢复原有内容"
        }
    }
}

enum GIFSharing {
    static func copyGIF(
        at url: URL,
        to pasteboard: NSPasteboard,
        write: (NSPasteboard, [NSPasteboardItem]) -> Bool = {
            $0.writeObjects($1)
        }
    ) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw GIFSharingError.cannotReadFile(error.localizedDescription)
        }

        let item = NSPasteboardItem()
        item.setData(data, forType: NSPasteboard.PasteboardType(UTType.gif.identifier))
        item.setString(url.absoluteString, forType: .fileURL)
        item.setString(url.path, forType: .string)

        // 只有文件成功读取后才替换剪贴板，避免失败时丢失用户原有内容。
        let previousContents = snapshot(of: pasteboard)
        pasteboard.clearContents()
        guard write(pasteboard, [item]) else {
            guard restore(previousContents, to: pasteboard) else {
                throw GIFSharingError.pasteboardRestoreFailed
            }
            throw GIFSharingError.pasteboardRejected
        }
    }

    private static func snapshot(
        of pasteboard: NSPasteboard
    ) -> [[(type: NSPasteboard.PasteboardType, data: Data)]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type: type, data: data)
            }
        }
    }

    private static func restore(
        _ contents: [[(type: NSPasteboard.PasteboardType, data: Data)]],
        to pasteboard: NSPasteboard
    ) -> Bool {
        pasteboard.clearContents()
        var succeeded = true
        for itemContents in contents where !itemContents.isEmpty {
            let item = NSPasteboardItem()
            for content in itemContents {
                item.setData(content.data, forType: content.type)
            }
            if !pasteboard.writeObjects([item]) { succeeded = false }
        }
        return succeeded
    }
}
