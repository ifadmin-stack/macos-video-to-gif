import AppKit
import CoreGraphics

/// 预览与正式导出共用的位图渲染器：先缩放，再按输出像素绘制文字。
enum GIFRenderer {
    static func render(
        image: CGImage,
        maxWidth: Int,
        captions: [Caption],
        time: Double
    ) -> CGImage? {
        guard let scaled = scale(image, maxWidth: maxWidth) else { return nil }
        let activeCaptions = captions.filter { $0.isActive(at: time) }
        guard !activeCaptions.isEmpty else { return scaled }
        return drawCaptions(activeCaptions, on: scaled)
    }

    private static func scale(_ image: CGImage, maxWidth: Int) -> CGImage? {
        guard maxWidth > 0 else { return nil }
        guard image.width != maxWidth else { return image }
        let scale = Double(maxWidth) / Double(image.width)
        let width = maxWidth
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = makeContext(width: width, height: height) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func drawCaptions(_ captions: [Caption], on image: CGImage) -> CGImage? {
        guard let context = makeContext(width: image.width, height: image.height) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for caption in captions {
            draw(caption, canvas: CGSize(width: image.width, height: image.height))
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    private static func draw(_ caption: Caption, canvas: CGSize) {
        let fontSize = min(144, max(8, CGFloat(caption.fontSize)))
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: nsColor(for: caption.color),
            .paragraphStyle: paragraph
        ]
        if caption.hasStroke {
            attributes[.strokeColor] = caption.color == .black ? NSColor.white : NSColor.black
            attributes[.strokeWidth] = -2.5
        }

        let text = NSAttributedString(string: caption.text, attributes: attributes)
        let maxWidth = max(1, canvas.width * 0.92)
        let bounds = text.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).integral
        let margin = max(6, canvas.height * 0.04)
        let x = (canvas.width - bounds.width) / 2
        let y: CGFloat
        switch caption.position {
        case .top:
            y = canvas.height - margin - bounds.height
        case .middle:
            y = (canvas.height - bounds.height) / 2
        case .bottom:
            y = margin
        }
        text.draw(with: CGRect(origin: CGPoint(x: x, y: y), size: bounds.size), options: [
            .usesLineFragmentOrigin,
            .usesFontLeading
        ])
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func nsColor(for color: CaptionColor) -> NSColor {
        switch color {
        case .white: return .white
        case .yellow: return .yellow
        case .black: return .black
        case .red: return .red
        case .cyan: return .cyan
        }
    }
}
