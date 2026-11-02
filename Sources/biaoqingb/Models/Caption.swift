import Foundation

enum CaptionPosition: String, CaseIterable, Identifiable {
    case top
    case middle
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: return "顶部"
        case .middle: return "中间"
        case .bottom: return "底部"
        }
    }
}

enum CaptionColor: String, CaseIterable, Identifiable {
    case white
    case yellow
    case black
    case red
    case cyan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "白色"
        case .yellow: return "黄色"
        case .black: return "黑色"
        case .red: return "红色"
        case .cyan: return "青色"
        }
    }
}

struct Caption: Identifiable, Equatable {
    var id: UUID
    var text: String
    var start: Double
    var end: Double
    var position: CaptionPosition
    var fontSize: Double
    var color: CaptionColor
    var hasStroke: Bool

    init(
        id: UUID = UUID(),
        text: String,
        start: Double,
        end: Double,
        position: CaptionPosition = .bottom,
        fontSize: Double = 32,
        color: CaptionColor = .white,
        hasStroke: Bool = true
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.position = position
        self.fontSize = fontSize
        self.color = color
        self.hasStroke = hasStroke
    }

    /// 使用左闭右开区间，避免相邻字幕在边界帧重复出现。
    func isActive(at time: Double) -> Bool {
        guard end > start, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return start <= time && time < end
    }
}
