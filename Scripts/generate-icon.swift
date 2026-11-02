#!/usr/bin/env swift
// 生成 AppIcon.iconset（1024/512/256/128/32/16）
// 设计：深紫渐变 + 对话气泡笑脸 + 薄荷绿 GIF 徽章
import AppKit

private let ink = NSColor(calibratedRed: 0.075, green: 0.065, blue: 0.20, alpha: 1)
private let mint = NSColor(calibratedRed: 0.36, green: 0.93, blue: 0.72, alpha: 1)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    guard let image = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("无法创建位图")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("无法创建图标绘图上下文")
    }
    let s = size / 1024.0

    // macOS 圆角底板，四周保留安全边距。
    let bodyRect = CGRect(x: 96*s, y: 96*s, width: 832*s, height: 832*s)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 190*s, yRadius: 190*s)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14*s),
        blur: 26*s,
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )
    NSColor.white.setFill()
    bodyPath.fill()
    ctx.restoreGState()

    ctx.saveGState()
    bodyPath.addClip()
    let backgroundColors = [
        NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.28, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.31, green: 0.20, blue: 0.64, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.48, green: 0.28, blue: 0.88, alpha: 1).cgColor
    ] as CFArray
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: backgroundColors,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(
        background,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
        options: []
    )

    // 右上角的轻量光晕，增加层次但不干扰主体。
    let glowColors = [
        NSColor.white.withAlphaComponent(0.20).cgColor,
        NSColor.white.withAlphaComponent(0).cgColor
    ] as CFArray
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: glowColors,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 790*s, y: 800*s),
        startRadius: 0,
        endCenter: CGPoint(x: 790*s, y: 800*s),
        endRadius: 420*s,
        options: []
    )
    ctx.restoreGState()

    // 后层气泡形成“连续两帧”的视觉暗示。
    let backBubble = NSBezierPath(
        roundedRect: CGRect(x: 232*s, y: 344*s, width: 640*s, height: 408*s),
        xRadius: 120*s,
        yRadius: 120*s
    )
    let backTail = NSBezierPath()
    backTail.move(to: CGPoint(x: 362*s, y: 366*s))
    backTail.line(to: CGPoint(x: 318*s, y: 250*s))
    backTail.line(to: CGPoint(x: 462*s, y: 346*s))
    backTail.close()
    mint.withAlphaComponent(0.30).setFill()
    backTail.fill()
    backBubble.fill()

    // 前层对话气泡与尾巴。
    let frontTail = NSBezierPath()
    frontTail.move(to: CGPoint(x: 322*s, y: 346*s))
    frontTail.line(to: CGPoint(x: 278*s, y: 230*s))
    frontTail.line(to: CGPoint(x: 422*s, y: 326*s))
    frontTail.close()
    NSColor.white.setFill()
    frontTail.fill()

    let frontBubble = NSBezierPath(
        roundedRect: CGRect(x: 192*s, y: 316*s, width: 640*s, height: 408*s),
        xRadius: 120*s,
        yRadius: 120*s
    )
    frontBubble.fill()

    // 眨眼笑脸：使用粗实线和简单几何，确保 16px 仍有辨识度。
    ink.setFill()
    ink.setStroke()
    ctx.setLineCap(.round)
    ctx.setLineWidth(30*s)
    ctx.fillEllipse(in: CGRect(x: 366*s, y: 534*s, width: 52*s, height: 52*s))
    ctx.move(to: CGPoint(x: 600*s, y: 560*s))
    ctx.addLine(to: CGPoint(x: 664*s, y: 560*s))
    ctx.strokePath()

    let smile = NSBezierPath()
    smile.move(to: CGPoint(x: 408*s, y: 466*s))
    smile.curve(
        to: CGPoint(x: 616*s, y: 466*s),
        controlPoint1: CGPoint(x: 438*s, y: 386*s),
        controlPoint2: CGPoint(x: 586*s, y: 386*s)
    )
    smile.lineWidth = 30*s
    smile.lineCapStyle = .round
    smile.stroke()

    // GIF 徽章：独立于气泡，远看也能识别输出格式。
    let badgeRect = CGRect(x: 312*s, y: 180*s, width: 400*s, height: 154*s)
    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 77*s, yRadius: 77*s)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -7*s),
        blur: 14*s,
        color: NSColor.black.withAlphaComponent(0.22).cgColor
    )
    mint.setFill()
    badgePath.fill()
    ctx.restoreGState()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 92*s),
        .foregroundColor: ink,
        .paragraphStyle: paragraph
    ]
    let text = NSString("GIF")
    let textSize = text.size(withAttributes: attributes)
    text.draw(
        at: CGPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        ),
        withAttributes: attributes
    )

    NSGraphicsContext.restoreGraphicsState()
    return image
}

// ---- 输出 iconset ----
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: root)
try! FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in specs {
    let rep = drawIcon(size: px)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("导出 PNG 失败: \(name)")
    }
    try! png.write(to: URL(fileURLWithPath: "\(root)/\(name)"))
}

let previewPath = "\(root)/../icon-preview.png"
try? FileManager.default.removeItem(atPath: previewPath)
try! FileManager.default.copyItem(
    atPath: "\(root)/icon_512x512@2x.png",
    toPath: previewPath
)
print("iconset 生成完成: \(root)")
