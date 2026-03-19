import SwiftUI
import AVFoundation

// MARK: - VideoTrimView

struct VideoTrimView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let onComplete: (URL, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var currentTime: Double = 0
    @State private var filmstripThumbnails: [UIImage] = []
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var playbackTimer: Timer?

    private let minimumDuration: Double = 1.0
    private let thumbnailCount = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                videoPreviewSection
                trimControlsSection
            }

            if isExporting {
                exportOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    cleanUpPlayer()
                    dismiss()
                }
                .foregroundColor(.white)
                .frame(minWidth: 44, minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Trim") {
                    handleExport()
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isExporting)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            setupPlayer()
            generateFilmstrip()
        }
        .onDisappear {
            cleanUpPlayer()
        }
        .alert("Export Failed", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let exportError { Text(exportError) }
        }
    }

    // MARK: - Video Preview

    private var videoPreviewSection: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * (5.0 / 4.0)

            ZStack {
                Color.black

                if let player {
                    SimpleVideoPlayerView(player: player)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                }

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatTime(trimEnd - trimStart))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(12)
                    }
                }
                .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    // MARK: - Trim Controls

    private var trimControlsSection: some View {
        VStack(spacing: InvlogTheme.Spacing.sm) {
            Spacer().frame(height: InvlogTheme.Spacing.md)

            // Time labels
            HStack {
                Text(formatTime(trimStart))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.brandTextSecondary)
                Spacer()
                Text(formatTime(trimEnd))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.brandTextSecondary)
            }
            .padding(.horizontal, InvlogTheme.Spacing.lg)

            // Filmstrip with trim handles
            filmstripWithHandles
                .padding(.horizontal, InvlogTheme.Spacing.md)

            // Hint text
            Text("Drag handles to trim. Min \(Int(minimumDuration))s.")
                .font(InvlogTheme.caption(11))
                .foregroundColor(Color.brandTextTertiary)

            Spacer().frame(height: InvlogTheme.Spacing.lg)
        }
        .background(Color.black)
    }

    private var filmstripWithHandles: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let handleWidth: CGFloat = 16
            let usableWidth = totalWidth - handleWidth * 2

            ZStack(alignment: .leading) {
                // Filmstrip thumbnails
                HStack(spacing: 0) {
                    ForEach(Array(filmstripThumbnails.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: totalWidth / CGFloat(thumbnailCount), height: 48)
                            .clipped()
                    }
                }
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Dimmed areas outside trim range
                if duration > 0 {
                    let startFraction = trimStart / duration
                    let endFraction = trimEnd / duration

                    // Left dim
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: usableWidth * startFraction + handleWidth, height: 48)

                    // Right dim
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: usableWidth * (1.0 - endFraction) + handleWidth, height: 48)
                    }

                    // Left handle
                    trimHandle(isStart: true)
                        .offset(x: usableWidth * startFraction)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let fraction = max(0, min(value.location.x / usableWidth, 1.0))
                                    let newStart = fraction * duration
                                    let maxStart = trimEnd - minimumDuration
                                    trimStart = min(max(0, newStart), max(0, maxStart))
                                    seekToTrimStart()
                                }
                        )

                    // Right handle
                    trimHandle(isStart: false)
                        .offset(x: usableWidth * (endFraction) + handleWidth)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let fraction = max(0, min((value.location.x - handleWidth) / usableWidth, 1.0))
                                    let newEnd = fraction * duration
                                    let minEnd = trimStart + minimumDuration
                                    trimEnd = max(min(newEnd, duration), min(duration, minEnd))
                                    seekToTrimEnd()
                                }
                        )

                    // Playhead indicator
                    if duration > 0 {
                        let playFraction = currentTime / duration
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 52)
                            .offset(x: handleWidth + usableWidth * playFraction)
                    }
                }
            }
        }
        .frame(height: 52)
    }

    private func trimHandle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.brandPrimary)
            .frame(width: 16, height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: 20)
            )
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        duration = CMTimeGetSeconds(asset.duration)
        trimEnd = duration

        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            // Loop within trim range
            let startTime = CMTime(seconds: trimStart, preferredTimescale: 600)
            avPlayer.seek(to: startTime)
            avPlayer.play()
        }

        player = avPlayer
        avPlayer.play()

        // Start playback timer for playhead tracking
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let player = self.player else { return }
            let time = CMTimeGetSeconds(player.currentTime())
            DispatchQueue.main.async {
                self.currentTime = time
                // Loop within trim range
                if time >= self.trimEnd {
                    let startTime = CMTime(seconds: self.trimStart, preferredTimescale: 600)
                    player.seek(to: startTime)
                }
            }
        }
    }

    private func cleanUpPlayer() {
        // Invalidate timer first to stop accessing player
        playbackTimer?.invalidate()
        playbackTimer = nil
        let playerRef = player
        player = nil
        playerRef?.pause()
        if let currentItem = playerRef?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
    }

    private func seekToTrimStart() {
        let time = CMTime(seconds: trimStart, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func seekToTrimEnd() {
        let time = CMTime(seconds: max(trimEnd - 0.1, trimStart), preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Filmstrip Generation

    private func generateFilmstrip() {
        let url = videoURL
        let count = thumbnailCount
        Task {
            let thumbs = await Task.detached(priority: .userInitiated) { () -> [UIImage] in
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 80, height: 80)

                let totalDuration = CMTimeGetSeconds(asset.duration)
                guard totalDuration > 0 else { return [] }

                var images: [UIImage] = []
                for i in 0..<count {
                    let time = CMTime(seconds: totalDuration * Double(i) / Double(count), preferredTimescale: 600)
                    if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                        images.append(UIImage(cgImage: cgImage))
                    }
                }
                return images
            }.value

            filmstripThumbnails = thumbs
        }
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                Text("Exporting...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Export

    private func handleExport() {
        // If no trimming, pass through
        if trimStart == 0 && trimEnd >= duration - 0.1 {
            cleanUpPlayer()
            onComplete(videoURL, thumbnail)
            dismiss()
            return
        }

        isExporting = true
        Task {
            do {
                let (exportedURL, exportedThumb) = try await exportTrimmed()
                await MainActor.run {
                    isExporting = false
                    cleanUpPlayer()
                    onComplete(exportedURL, exportedThumb)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func exportTrimmed() async throws -> (URL, UIImage) {
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoTrim", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
        }

        let startTime = CMTime(seconds: trimStart, preferredTimescale: 600)
        let endTime = CMTime(seconds: trimEnd, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "VideoTrim", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }

        // Generate thumbnail from trimmed video
        let trimmedAsset = AVURLAsset(url: outputURL)
        let generator = AVAssetImageGenerator(asset: trimmedAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)

        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let trimmedThumb = UIImage(cgImage: cgImage)

        return (outputURL, trimmedThumb)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = Int(total) % 60
        let frac = Int((total.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, frac)
    }
}

// Uses shared SimpleVideoPlayerView from Components/
