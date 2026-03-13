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
    @State private var hasFailed = false
    @State private var statusObserver: AnyCancellable?
    @State private var loopObserver: Any?
    @ObservedObject private var muteManager = VideoMuteManager.shared

    var body: some View {
        ZStack {
            // Video player (behind thumbnail, always present when player exists)
            if let player {
                VideoPlayerView(player: player)
                    .opacity(isPlayerReady ? 1 : 0)
                    .onDisappear {
                        player.pause()
                    }
            }

            // Thumbnail / placeholder (shown while video buffers, fades out)
            if !isPlayerReady {
                ZStack {
                    if hasFailed {
                        // Show static thumbnail for failed videos
                        thumbnailOrPlaceholder
                        Image(systemName: "play.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        thumbnailOrPlaceholder
                        ShimmerView()
                            .opacity(0.4)
                    }
                }
                .transition(.opacity)
            }

            // Mute/unmute button
            if isPlayerReady {
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
        }
        .onAppear {
            isVisible = true
            setupPlayer()
        }
        .onDisappear {
            isVisible = false
            tearDownPlayer()
        }
        .onChange(of: muteManager.isMuted) { muted in
            player?.isMuted = muted
        }
    }

    @ViewBuilder
    private var thumbnailOrPlaceholder: some View {
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
    }

    private func setupPlayer() {
        guard player == nil else {
            if isVisible {
                player?.play()
            }
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = muteManager.isMuted
        avPlayer.actionAtItemEnd = .none

        // Loop video — store observer token for proper cleanup
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }

        // Observe player item status to know when video is ready
        statusObserver = avPlayer.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .readyToPlay:
                    // Small delay to ensure first frame is rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isPlayerReady = true
                        }
                    }
                    statusObserver?.cancel()
                    statusObserver = nil
                case .failed:
                    hasFailed = true
                    statusObserver?.cancel()
                    statusObserver = nil
                default:
                    break
                }
            }

        player = avPlayer
        if isVisible {
            avPlayer.play()
        }
    }

    private func tearDownPlayer() {
        cleanupObservers()
        player?.pause()
        player = nil
        isPlayerReady = false
        hasFailed = false
    }

    private func cleanupObservers() {
        statusObserver?.cancel()
        statusObserver = nil
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
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
