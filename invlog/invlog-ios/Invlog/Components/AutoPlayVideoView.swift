import SwiftUI
import AVKit
import Combine
@preconcurrency import NukeUI

struct AutoPlayVideoView: View {
    let url: URL
    let thumbnailUrl: URL?
    let blurhash: String?

    @State private var player: AVPlayer?
    @State private var isVisible = false
    @State private var isPlayerReady = false
    @State private var statusObserver: AnyCancellable?
    @ObservedObject private var muteManager = VideoMuteManager.shared

    var body: some View {
        ZStack {
            // Thumbnail / placeholder (shown while video buffers)
            if !isPlayerReady {
                ZStack {
                    if let thumbnailUrl {
                        LazyImage(url: thumbnailUrl) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else if let blurhash {
                                BlurhashView(blurhash: blurhash)
                            } else {
                                Rectangle().fill(Color(.systemGray5))
                            }
                        }
                    } else if let blurhash {
                        BlurhashView(blurhash: blurhash)
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    ShimmerView()
                        .opacity(0.4)
                }
            }

            // Video player
            if let player {
                VideoPlayerView(player: player)
                    .onDisappear {
                        player.pause()
                    }
            }

            // Mute/unmute button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        muteManager.toggle()
                    } label: {
                        Image(systemName: muteManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
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
            if let item = player?.currentItem {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            }
        }
        .onChange(of: muteManager.isMuted) { muted in
            player?.isMuted = muted
        }
    }

    private func setupPlayer() {
        guard player == nil else {
            if isVisible { player?.play() }
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = muteManager.isMuted
        avPlayer.actionAtItemEnd = .none

        // Loop video
        let item = avPlayer.currentItem
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }

        // Observe player item status to know when video is ready
        statusObserver = avPlayer.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                if status == .readyToPlay {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isPlayerReady = true
                    }
                    statusObserver?.cancel()
                }
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
