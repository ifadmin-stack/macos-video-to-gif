import Foundation
import AppKit
import UniformTypeIdentifiers

enum GIFSharingTests {
    static func testCopyContainsGIFDataAndFileURL() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("biaoqingb-share-test-\(UUID().uuidString).gif")
        let data = Data("GIF89a-test".utf8)
        try data.write(to: url)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("biaoqingb-test-\(UUID().uuidString)"))
        defer {
            try? FileManager.default.removeItem(at: url)
            pasteboard.clearContents()
        }

        try GIFSharing.copyGIF(at: url, to: pasteboard)

        let item = try unwrap(pasteboard.pasteboardItems?.first)
        try expectEqual(item.data(forType: NSPasteboard.PasteboardType(UTType.gif.identifier)), data)
        try expectEqual(item.string(forType: .fileURL), url.absoluteString)
    }

    static func testReadFailureDoesNotClearExistingPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("biaoqingb-test-\(UUID().uuidString)"))
        defer { pasteboard.clearContents() }
        pasteboard.clearContents()
        pasteboard.setString("保留内容", forType: .string)
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).gif")
        var didFail = false

        do {
            try GIFSharing.copyGIF(at: missingURL, to: pasteboard)
        } catch {
            didFail = true
        }

        try expect(didFail, "文件不存在时应返回错误")
        try expectEqual(pasteboard.string(forType: .string), "保留内容")
    }

    static func testWriteFailureRestoresExistingPasteboard() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("biaoqingb-share-test-\(UUID().uuidString).gif")
        try Data("GIF89a-test".utf8).write(to: url)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("biaoqingb-test-\(UUID().uuidString)"))
        defer {
            try? FileManager.default.removeItem(at: url)
            pasteboard.clearContents()
        }
        pasteboard.clearContents()
        pasteboard.setString("保留内容", forType: .string)
        var didFail = false

        do {
            try GIFSharing.copyGIF(at: url, to: pasteboard, write: { _, _ in false })
        } catch {
            didFail = true
        }

        try expect(didFail, "剪贴板拒绝写入时应返回错误")
        try expectEqual(pasteboard.string(forType: .string), "保留内容")
    }
}
