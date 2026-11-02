import SwiftUI
import AVFoundation
import AppKit

/// AVPlayerLayer 包装的播放视图
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: PlayerNSView, context: Context) {}
}

final class PlayerNSView: NSView {
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVPlayerLayer()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func makeBackingLayer() -> CALayer { AVPlayerLayer() }
}
