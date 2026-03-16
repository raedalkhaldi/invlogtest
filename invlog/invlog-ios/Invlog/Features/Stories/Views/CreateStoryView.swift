import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage

struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isVideo = false
    @State private var errorMessage: String?
    @State private var isLoadingMedia = false
    @State private var showCamera = false
    @State private var showVideoRecorder = false
    @State private var showVideoTrim = false
    @State private var caption = ""
    @State private var showPlacePicker = false
    @State private var selectedPlace: SelectedPlace?

    // Inline filter state
    @State private var selectedFilter: VideoFilter = .original
    @State private var selectedFilterIndex: Int = 0
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var filterDragOffset: CGFloat = 0
    @State private var isExportingFilter = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoadingMedia {
                    ProgressView("Loading media...")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if selectedImage != nil || selectedVideoURL != nil {
                    // Post-recording / post-selection screen
                    mediaPreviewScreen
                } else {
                    // Media picker screen
                    mediaPickerScreen
                }

                if isExportingFilter {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.2)
                            Text("Applying filter...")
                                .font(InvlogTheme.body(14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .navigationTitle("New Vlog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                        .frame(minWidth: 44, minHeight: 44)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if selectedImage != nil || selectedVideoURL != nil {
                        Button("Share") {
                            handleShare()
                        }
                        .font(InvlogTheme.body(15, weight: .bold))
                        .foregroundColor(Color.brandPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(isExportingFilter)
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task { await loadMedia(from: newItem) }
            }
            .sheet(isPresented: $showPlacePicker) {
                PlacePickerView(selectedPlace: $selectedPlace)
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView { image in
                    selectedImage = image
                    selectedVideoURL = nil
                    isVideo = false
                }
            }
            .fullScreenCover(isPresented: $showVideoRecorder) {
                NavigationStack {
                    VineRecorderView(maxSeconds: 60, holdToRecord: false) { url, thumbnail in
                        selectedVideoURL = url
                        selectedImage = thumbnail
                        isVideo = true
                        showVideoRecorder = false
                        generateFilterThumbnails()
                    }
                }
            }
            .sheet(isPresented: $showVideoTrim) {
                if let videoURL = selectedVideoURL, let thumb = selectedImage {
                    NavigationStack {
                        VideoTrimView(videoURL: videoURL, thumbnail: thumb) { trimmedURL, trimmedThumb in
                            selectedVideoURL = trimmedURL
                            selectedImage = trimmedThumb
                            showVideoTrim = false
                            // Regenerate filter thumbnails for trimmed video
                            generateFilterThumbnails()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Media Preview Screen (post-recording)

    private var mediaPreviewScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Video preview with black background (proper aspect ratio)
                ZStack {
                    Color.black

                    if isVideo, let videoURL = selectedVideoURL {
                        StoryVideoPreview(url: videoURL)
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.width * 16 / 9)
                    } else if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.width * 16 / 9)
                    }
                }
                .frame(height: min(UIScreen.main.bounds.width * 16 / 9, UIScreen.main.bounds.height * 0.5))
                .clipped()

                // Filter strip (only for videos)
                if isVideo {
                    filterStripSection
                }

                // Action buttons row (Edit/Trim)
                if isVideo {
                    HStack(spacing: 16) {
                        Button {
                            showVideoTrim = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "scissors")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Trim")
                                    .font(InvlogTheme.body(14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Change")
                                    .font(InvlogTheme.body(14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Caption + Place section
                VStack(spacing: 12) {
                    // Caption field
                    TextField("Add a caption...", text: $caption, axis: .vertical)
                        .font(InvlogTheme.body(15))
                        .foregroundColor(.white)
                        .lineLimit(2...5)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    // Place picker
                    Button {
                        showPlacePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.brandPrimary)
                            if let place = selectedPlace {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(InvlogTheme.body(14, weight: .semibold))
                                        .foregroundColor(.white)
                                    if !place.address.isEmpty {
                                        Text(place.address)
                                            .font(InvlogTheme.caption(12))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                }
                            } else {
                                Text("Add Location")
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Filter Strip

    private var filterStripSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let itemWidth: CGFloat = 64
                let spacing: CGFloat = 10
                let totalItemWidth = itemWidth + spacing
                let centerOffset = (geo.size.width - itemWidth) / 2

                HStack(spacing: spacing) {
                    ForEach(Array(VideoFilter.allCases.enumerated()), id: \.element) { index, filter in
                        Button {
                            selectedFilterIndex = index
                            selectedFilter = filter
                        } label: {
                            VStack(spacing: 4) {
                                if let thumbImage = filterThumbnails[filter] {
                                    Image(uiImage: thumbImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedFilterIndex == index ? Color.brandPrimary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 52, height: 52)
                                }

                                Text(filter.rawValue)
                                    .font(.system(size: 10, weight: selectedFilterIndex == index ? .bold : .regular))
                                    .foregroundColor(selectedFilterIndex == index ? Color.brandPrimary : .white.opacity(0.6))
                            }
                            .frame(width: itemWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .offset(x: centerOffset - CGFloat(selectedFilterIndex) * totalItemWidth + filterDragOffset)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: selectedFilterIndex)
                .gesture(
                    DragGesture()
                        .onChanged { value in filterDragOffset = value.translation.width }
                        .onEnded { value in
                            let threshold: CGFloat = totalItemWidth * 0.3
                            var newIndex = selectedFilterIndex
                            if value.translation.width < -threshold {
                                newIndex = min(selectedFilterIndex + 1, VideoFilter.allCases.count - 1)
                            } else if value.translation.width > threshold {
                                newIndex = max(selectedFilterIndex - 1, 0)
                            }
                            filterDragOffset = 0
                            selectedFilterIndex = newIndex
                            selectedFilter = VideoFilter.allCases[newIndex]
                        }
                )
            }
            .frame(height: 76)

            // Dots
            HStack(spacing: 4) {
                ForEach(0..<VideoFilter.allCases.count, id: \.self) { i in
                    Circle()
                        .fill(i == selectedFilterIndex ? Color.brandPrimary : Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Media Picker Screen

    private var mediaPickerScreen: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("Add to Your Vlog")
                .font(InvlogTheme.heading(20, weight: .bold))
                .foregroundColor(.white)

            Text("Record a video, take a photo, or choose from your library.")
                .font(InvlogTheme.body(14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("Photo")
                    }
                    .font(InvlogTheme.body(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                }

                Button {
                    showVideoRecorder = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                        Text("Video")
                    }
                    .font(InvlogTheme.body(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.brandPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                }
            }
            .padding(.horizontal, 48)

            PhotosPicker(
                selection: $selectedItem,
                matching: .any(of: [.images, .videos])
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                }
                .font(InvlogTheme.body(14, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }

    // MARK: - Actions

    private func handleShare() {
        if selectedFilter != .original, isVideo, let videoURL = selectedVideoURL {
            // Export with filter applied
            isExportingFilter = true
            Task { @MainActor in
                do {
                    let (exportedURL, filteredThumb) = try await exportWithFilter(videoURL: videoURL, filter: selectedFilter)
                    isExportingFilter = false
                    doShare(videoURL: exportedURL, thumbnail: filteredThumb)
                } catch {
                    isExportingFilter = false
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            doShare(videoURL: selectedVideoURL, thumbnail: selectedImage)
        }
    }

    private func doShare(videoURL: URL?, thumbnail: UIImage?) {
        let mediaItem: MediaItem
        if isVideo, let videoURL, let thumbnail {
            mediaItem = .video(videoURL, thumbnail)
        } else if let image = selectedImage {
            mediaItem = .image(image)
        } else {
            errorMessage = "No media selected."
            return
        }

        Task { @MainActor in
            StoryUploadManager.shared.upload(
                mediaItem: mediaItem,
                caption: caption.isEmpty ? nil : caption,
                locationName: selectedPlace?.name,
                restaurantId: selectedPlace?.restaurantId
            )
        }
        dismiss()
    }

    // MARK: - Filter Export

    private func exportWithFilter(videoURL: URL, filter: VideoFilter) async throws -> (URL, UIImage) {
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filtered_\(UUID().uuidString).mp4")

        let videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            let output = VideoFilterView.applyCIFilterPublic(to: request.sourceImage, filter: filter)
            request.finish(with: output, context: nil)
        })

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoFilter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoFilter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed."])
        }

        // Generate filtered thumbnail
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let ciImage = CIImage(cgImage: cgImage)
        let filteredCI = VideoFilterView.applyCIFilterPublic(to: ciImage, filter: filter)
        let context = CIContext()
        guard let filteredCG = context.createCGImage(filteredCI, from: filteredCI.extent) else {
            throw NSError(domain: "VideoFilter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail."])
        }

        return (outputURL, UIImage(cgImage: filteredCG))
    }

    // MARK: - Helpers

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingMedia = true
        errorMessage = nil
        selectedImage = nil
        selectedVideoURL = nil
        isVideo = false
        selectedFilter = .original
        selectedFilterIndex = 0

        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            let thumbnail = await generateThumbnail(from: movie.url)
            selectedImage = thumbnail
            selectedVideoURL = movie.url
            isVideo = true
            generateFilterThumbnails()
        } else if let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) {
            selectedImage = image
            isVideo = false
        }
        isLoadingMedia = false
    }

    private func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func generateFilterThumbnails() {
        guard let url = selectedVideoURL else { return }
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> [VideoFilter: UIImage] in
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 150, height: 150)

                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return [:] }

                let sourceCI = CIImage(cgImage: cgImage)
                let context = CIContext()
                var thumbs: [VideoFilter: UIImage] = [:]

                for filter in VideoFilter.allCases {
                    let filteredCI = VideoFilterView.applyCIFilterPublic(to: sourceCI, filter: filter)
                    if let filteredCG = context.createCGImage(filteredCI, from: filteredCI.extent) {
                        thumbs[filter] = UIImage(cgImage: filteredCG)
                    }
                }
                return thumbs
            }.value

            filterThumbnails = result
        }
    }
}

// MARK: - Video Preview (black background, proper aspect ratio)

private struct StoryVideoPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        let player = AVPlayer(url: url)
        player.isMuted = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(playerLayer)
        view.playerLayer = playerLayer
        player.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class PlayerContainerView: UIView {
        var playerLayer: AVPlayerLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }

    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?

        deinit {
            if let item = player?.currentItem {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            }
            player?.pause()
        }
    }
}
