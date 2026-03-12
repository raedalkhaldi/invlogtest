import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - VideoFilter Enum

enum VideoFilter: String, CaseIterable {
    case original = "Original"
    case vivid = "Vivid"
    case warm = "Warm"
    case cool = "Cool"
    case noir = "Noir"
    case fade = "Fade"
}

// MARK: - VideoFilterView

struct VideoFilterView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let onComplete: (URL, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: VideoFilter = .original
    @State private var player: AVPlayer?
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var isExporting = false
    @State private var exportError: String?

    private let ciContext = CIContext()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Video preview area
                videoPreviewSection

                // Filter selection strip
                filterSelectionSection
            }

            // Export loading overlay
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
                Button("Use This") {
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
            generateFilterThumbnails()
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
            if let exportError {
                Text(exportError)
            }
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
                    FilteredVideoPlayerView(player: player)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    // MARK: - Filter Selection

    private var filterSelectionSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: InvlogTheme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    ForEach(VideoFilter.allCases, id: \.self) { filter in
                        filterThumbnailButton(for: filter)
                    }
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
            }

            Spacer()
                .frame(height: InvlogTheme.Spacing.lg)
        }
        .background(Color.black)
    }

    private func filterThumbnailButton(for filter: VideoFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            guard selectedFilter != filter else { return }
            selectedFilter = filter
            applyFilterToPlayer(filter)
        } label: {
            VStack(spacing: 6) {
                if let thumbImage = filterThumbnails[filter] {
                    Image(uiImage: thumbImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(
                                    isSelected ? Color.brandPrimary : Color.brandBorder,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                } else {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(
                                    isSelected ? Color.brandPrimary : Color.brandBorder,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                }

                Text(filter.rawValue)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(isSelected ? Color.brandPrimary : Color.brandTextSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.rawValue) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Export Overlay

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: InvlogTheme.Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("Applying filter...")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(InvlogTheme.Spacing.xl)
            .background(Color.brandText.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        avPlayer.play()
    }

    private func cleanUpPlayer() {
        player?.pause()
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        player = nil
    }

    // MARK: - Apply Filter to Player

    private func applyFilterToPlayer(_ filter: VideoFilter) {
        guard let player else { return }

        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        if filter == .original {
            // No video composition needed for original
            playerItem.videoComposition = nil
        } else {
            let composition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
                let output = self.applyCIFilter(to: request.sourceImage, filter: filter)
                request.finish(with: output, context: nil)
            })
            playerItem.videoComposition = composition
        }

        // Preserve playback position
        let currentTime = player.currentTime()

        // Remove observer from old item
        if let oldItem = player.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: oldItem
            )
        }

        // Add observer for new item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.replaceCurrentItem(with: playerItem)
        player.seek(to: currentTime)
        player.play()
    }

    // MARK: - Filter Thumbnail Generation

    private func generateFilterThumbnails() {
        let url = videoURL
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> [VideoFilter: UIImage] in
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 150, height: 150)

                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                    return [:]
                }

                let sourceCI = CIImage(cgImage: cgImage)
                let context = CIContext()
                var thumbs: [VideoFilter: UIImage] = [:]

                for filter in VideoFilter.allCases {
                    let filteredCI = Self.applyCIFilterStatic(to: sourceCI, filter: filter)
                    if let filteredCG = context.createCGImage(filteredCI, from: filteredCI.extent) {
                        thumbs[filter] = UIImage(cgImage: filteredCG)
                    }
                }
                return thumbs
            }.value

            filterThumbnails = result
        }
    }

    // MARK: - Export

    private func handleExport() {
        if selectedFilter == .original {
            cleanUpPlayer()
            onComplete(videoURL, thumbnail)
            dismiss()
            return
        }

        isExporting = true
        Task {
            do {
                let (exportedURL, filteredThumbnail) = try await exportWithFilter()
                await MainActor.run {
                    isExporting = false
                    cleanUpPlayer()
                    onComplete(exportedURL, filteredThumbnail)
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

    private func exportWithFilter() async throws -> (URL, UIImage) {
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filtered_\(UUID().uuidString).mp4")

        let videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            let output = self.applyCIFilter(to: request.sourceImage, filter: self.selectedFilter)
            request.finish(with: output, context: nil)
        })

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(
                domain: "VideoFilter",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."]
            )
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "VideoFilter",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }

        // Generate filtered thumbnail
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let ciImage = CIImage(cgImage: cgImage)
        let filteredCI = applyCIFilter(to: ciImage, filter: selectedFilter)
        guard let filteredCG = ciContext.createCGImage(filteredCI, from: filteredCI.extent) else {
            throw NSError(
                domain: "VideoFilter",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to generate filtered thumbnail."]
            )
        }
        let filteredThumb = UIImage(cgImage: filteredCG)

        return (outputURL, filteredThumb)
    }

    // MARK: - CIFilter Application

    private static func applyCIFilterStatic(to image: CIImage, filter: VideoFilter) -> CIImage {
        applyCIFilterImpl(to: image, filter: filter)
    }

    private func applyCIFilter(to image: CIImage, filter: VideoFilter) -> CIImage {
        Self.applyCIFilterImpl(to: image, filter: filter)
    }

    private static func applyCIFilterImpl(to image: CIImage, filter: VideoFilter) -> CIImage {
        switch filter {
        case .original:
            return image

        case .vivid:
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(1.5, forKey: "inputSaturation")
            f.setValue(1.1, forKey: "inputContrast")
            return f.outputImage ?? image

        case .warm:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 5500, y: 0), forKey: "inputNeutral")
            return f.outputImage ?? image

        case .cool:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 8000, y: 0), forKey: "inputNeutral")
            return f.outputImage ?? image

        case .noir:
            let f = CIFilter(name: "CIPhotoEffectNoir")!
            f.setValue(image, forKey: kCIInputImageKey)
            return f.outputImage ?? image

        case .fade:
            let f = CIFilter(name: "CIPhotoEffectFade")!
            f.setValue(image, forKey: kCIInputImageKey)
            return f.outputImage ?? image
        }
    }
}

// MARK: - Filtered Video Player (UIViewRepresentable)

private struct FilteredVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> FilteredPlayerUIView {
        FilteredPlayerUIView(player: player)
    }

    func updateUIView(_ uiView: FilteredPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class FilteredPlayerUIView: UIView {
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
