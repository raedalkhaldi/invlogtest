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
    case beauty = "Beauty"
}

// MARK: - VideoFilterView

struct VideoFilterView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let onComplete: (URL, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: VideoFilter = .original
    @State private var selectedFilterIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var dragOffset: CGFloat = 0

    private let ciContext = CIContext()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Video preview area
                videoPreviewSection

                // Swipeable filter carousel
                filterCarouselSection
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
                    SimpleVideoPlayerView(player: player)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                }

                // Filter name overlay
                VStack {
                    Spacer()
                    Text(selectedFilter.rawValue)
                        .font(InvlogTheme.body(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    // MARK: - Swipeable Filter Carousel

    private var filterCarouselSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: InvlogTheme.Spacing.md)

            GeometryReader { geo in
                let itemWidth: CGFloat = 80
                let spacing: CGFloat = 12
                let totalItemWidth = itemWidth + spacing
                let centerOffset = (geo.size.width - itemWidth) / 2

                HStack(spacing: spacing) {
                    ForEach(Array(VideoFilter.allCases.enumerated()), id: \.element) { index, filter in
                        filterCarouselItem(for: filter, isSelected: selectedFilterIndex == index)
                            .frame(width: itemWidth)
                    }
                }
                .offset(x: centerOffset - CGFloat(selectedFilterIndex) * totalItemWidth + dragOffset)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: selectedFilterIndex)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = totalItemWidth * 0.3
                            var newIndex = selectedFilterIndex

                            if value.translation.width < -threshold {
                                newIndex = min(selectedFilterIndex + 1, VideoFilter.allCases.count - 1)
                            } else if value.translation.width > threshold {
                                newIndex = max(selectedFilterIndex - 1, 0)
                            }

                            // Also account for velocity
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            if velocity < -100 {
                                newIndex = min(selectedFilterIndex + 1, VideoFilter.allCases.count - 1)
                            } else if velocity > 100 {
                                newIndex = max(selectedFilterIndex - 1, 0)
                            }

                            dragOffset = 0
                            selectedFilterIndex = newIndex
                            let newFilter = VideoFilter.allCases[newIndex]
                            if selectedFilter != newFilter {
                                selectedFilter = newFilter
                                applyFilterToPlayer(newFilter)
                            }
                        }
                )
            }
            .frame(height: 100)

            // Page indicator dots
            HStack(spacing: 4) {
                ForEach(0..<VideoFilter.allCases.count, id: \.self) { i in
                    Circle()
                        .fill(i == selectedFilterIndex ? Color.brandPrimary : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.top, 8)

            Spacer()
                .frame(height: InvlogTheme.Spacing.lg)
        }
        .background(Color.black)
    }

    private func filterCarouselItem(for filter: VideoFilter, isSelected: Bool) -> some View {
        Button {
            guard let index = VideoFilter.allCases.firstIndex(of: filter) else { return }
            selectedFilterIndex = index
            selectedFilter = filter
            applyFilterToPlayer(filter)
        } label: {
            VStack(spacing: 6) {
                if let thumbImage = filterThumbnails[filter] {
                    Image(uiImage: thumbImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(
                                    isSelected ? Color.brandPrimary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .scaleEffect(isSelected ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                } else {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .scaleEffect(isSelected ? 1.1 : 0.9)
                }

                Text(filter.rawValue)
                    .font(InvlogTheme.caption(10, weight: isSelected ? .bold : .regular))
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
                let output = Self.applyCIFilter(to: request.sourceImage, filter: filter)
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
                    let filteredCI = Self.applyCIFilter(to: sourceCI, filter: filter)
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
            let output = Self.applyCIFilter(to: request.sourceImage, filter: self.selectedFilter)
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
        let filteredCI = Self.applyCIFilter(to: ciImage, filter: selectedFilter)
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

    /// Single public entry point for applying CI filters. Used by VideoFilterView itself,
    /// CreateStoryView inline filter export, and filter thumbnail generation.
    static func applyCIFilter(to image: CIImage, filter: VideoFilter) -> CIImage {
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

        case .beauty:
            // Skin smooth effect: blend a low-radius Gaussian blur with the original
            let blurFilter = CIFilter(name: "CIGaussianBlur")!
            blurFilter.setValue(image, forKey: kCIInputImageKey)
            blurFilter.setValue(3.0, forKey: kCIInputRadiusKey)
            guard let blurred = blurFilter.outputImage else { return image }

            // Crop blurred to original extent (CIGaussianBlur extends the image)
            let croppedBlur = blurred.cropped(to: image.extent)

            // Blend via color matrix to reduce opacity of blur (40%) and original (60%)
            let alphaFilter = CIFilter(name: "CIColorMatrix")!
            alphaFilter.setValue(croppedBlur, forKey: kCIInputImageKey)
            alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.4), forKey: "inputAVector")
            guard let semiTransparentBlur = alphaFilter.outputImage else { return image }

            // Also reduce original opacity to 0.6
            let origAlpha = CIFilter(name: "CIColorMatrix")!
            origAlpha.setValue(image, forKey: kCIInputImageKey)
            origAlpha.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            origAlpha.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            origAlpha.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            origAlpha.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.6), forKey: "inputAVector")
            guard let semiOriginal = origAlpha.outputImage else { return image }

            // Composite blur over original
            let composite = CIFilter(name: "CIAdditionCompositing")!
            composite.setValue(semiTransparentBlur, forKey: kCIInputImageKey)
            composite.setValue(semiOriginal, forKey: kCIInputBackgroundImageKey)
            guard let blended = composite.outputImage else { return image }

            // Slight brightness boost for a "glowy" beauty look
            let brighten = CIFilter(name: "CIColorControls")!
            brighten.setValue(blended, forKey: kCIInputImageKey)
            brighten.setValue(0.03, forKey: kCIInputBrightnessKey)
            brighten.setValue(1.05, forKey: "inputContrast")
            return brighten.outputImage ?? blended
        }
    }
}

// Uses shared SimpleVideoPlayerView from Components/
