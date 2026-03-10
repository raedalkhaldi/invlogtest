import SwiftUI
import AVKit

struct AutoPlayVideoView: View {
    let url: URL
    let thumbnailUrl: URL?
    let blurhash: String?

    @State private var player: AVPlayer?
    @State private var isMuted = true
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Video player
            if let player {
                VideoPlayerView(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else if let blurhash {
                BlurhashView(blurhash: blurhash)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }

            // Mute/unmute button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }
        }
        .onAppear {
            isVisible = true
            setupPlayer()
        }
        .onDisappear {
            isVisible = false
            player?.pause()
        }
    }

    private func setupPlayer() {
        guard player == nil else {
            if isVisible { player?.play() }
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = isMuted
        avPlayer.actionAtItemEnd = .none

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        if isVisible {
            avPlayer.play()
        }
    }
}

// UIKit wrapper for AVPlayerLayer (better performance than VideoPlayer)
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class PlayerUIView: UIView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
