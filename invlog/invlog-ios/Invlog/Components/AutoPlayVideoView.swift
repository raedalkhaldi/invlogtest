import SwiftUI
import AVKit
import Combine
@preconcurrency import NukeUI

struct AutoPlayVideoView: View {
    let url: URL
    let thumbnailUrl: URL?
    let blurhash: String?

    @State private var player: AVPlayer?
    @State private var isPlayerReady = false
    @State private var hasFailed = false
    @State private var statusObserver: AnyCancellable?
    @State private var loopObserver: Any?
    @State private var isInViewport = false
    @ObservedObject private var muteManager = VideoMuteManager.shared

    var body: some View {
        ZStack {
            // Video player (behind thumbnail, always present when player exists)
            if let player {
                VideoPlayerView(player: player, onVisibilityChanged: { visible in
                    guard visible != isInViewport else { return }
                    isInViewport = visible
                    if visible {
                        setupPlayer()
                    } else {
                        player.pause()
                    }
                })
                .opacity(isPlayerReady ? 1 : 0)
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
            // Defer to UIKit visibility tracking via VideoPlayerView
            setupPlayer()
        }
        .onDisappear {
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
            if isInViewport {
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
            avPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    avPlayer?.play()
                }
            }
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
        // Don't auto-play here — wait for UIKit visibility callback
    }

    private func tearDownPlayer() {
        cleanupObservers()
        player?.pause()
        player = nil
        isPlayerReady = false
        hasFailed = false
        isInViewport = false
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

// UIKit wrapper for AVPlayerLayer with scroll visibility tracking
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let onVisibilityChanged: (Bool) -> Void

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView(player: player)
        view.onVisibilityChanged = onVisibilityChanged
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.onVisibilityChanged = onVisibilityChanged
    }
}

private class PlayerUIView: UIView {
    let playerLayer: AVPlayerLayer
    var onVisibilityChanged: ((Bool) -> Void)?
    private var displayLink: CADisplayLink?
    private var wasVisible = false

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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startTracking()
        } else {
            stopTracking()
            if wasVisible {
                wasVisible = false
                onVisibilityChanged?(false)
            }
        }
    }

    private func startTracking() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(checkVisibility))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 5, maximum: 15, preferred: 10)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func checkVisibility() {
        guard let window else {
            if wasVisible {
                wasVisible = false
                onVisibilityChanged?(false)
            }
            return
        }

        let frameInWindow = convert(bounds, to: window)
        let screenBounds = window.bounds
        let viewMidY = frameInWindow.midY
        // Video is "visible" when its center is within the screen bounds
        let isVisible = viewMidY >= screenBounds.minY && viewMidY <= screenBounds.maxY
            && frameInWindow.maxY > screenBounds.minY && frameInWindow.minY < screenBounds.maxY

        if isVisible != wasVisible {
            wasVisible = isVisible
            onVisibilityChanged?(isVisible)
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}
