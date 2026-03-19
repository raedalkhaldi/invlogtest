import SwiftUI
import AVKit

/// A shared, reusable UIViewRepresentable for displaying an AVPlayer via AVPlayerLayer.
/// Replaces duplicate player wrappers across VideoFilterView, VideoTrimView,
/// VideoOverlayEditorView, and CreateStoryView.
struct SimpleVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> SimplePlayerUIView {
        SimplePlayerUIView(player: player, videoGravity: videoGravity)
    }

    func updateUIView(_ uiView: SimplePlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
}

class SimplePlayerUIView: UIView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.videoGravity = videoGravity
        playerLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
