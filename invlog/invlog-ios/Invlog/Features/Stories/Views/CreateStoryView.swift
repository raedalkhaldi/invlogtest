import SwiftUI
import PhotosUI
import AVFoundation

struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isVideo = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @StateObject private var uploadService = MediaUploadService()
    @State private var isLoadingMedia = false
    @State private var showCamera = false
    @State private var showVideoRecorder = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isLoadingMedia {
                    ProgressView("Loading media...")
                        .frame(maxHeight: 500)
                        .frame(maxWidth: .infinity)
                } else if selectedImage != nil || selectedVideoURL != nil {
                    // Preview
                    if isVideo, let videoURL = selectedVideoURL {
                        ZStack {
                            if let thumb = selectedImage {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFit()
                            }
                            StoryVideoPreview(url: videoURL)
                        }
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.lg))
                        .padding(.horizontal)
                    } else if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 500)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.lg))
                            .padding(.horizontal)
                    }

                    if isVideo {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.caption)
                            Text("Video vlog (up to 1 min)")
                                .font(InvlogTheme.caption(12, weight: .semibold))
                        }
                        .foregroundColor(Color.brandAccent)
                    }

                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadService.overallProgress)
                                .tint(Color.brandPrimary)
                                .padding(.horizontal)
                            Text("Uploading vlog...")
                                .font(InvlogTheme.caption(12))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Text("Change Media")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandPrimary)
                    }
                } else {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.brandTextTertiary)

                        Text("Add to Your Vlog")
                            .font(InvlogTheme.heading(20, weight: .bold))
                            .foregroundColor(Color.brandText)

                        Text("Take a photo, record a video (up to 1 min), or choose from your library.")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Camera buttons
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
                                .background(Color.brandSecondary)
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
                            .background(Color.brandCard)
                            .foregroundColor(Color.brandText)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                    .stroke(Color.brandBorder, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 48)
                    }

                    Spacer()
                }
            }
            .invlogScreenBackground()
            .navigationTitle("New Vlog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        Task { await uploadStory() }
                    }
                    .font(InvlogTheme.body(15, weight: .bold))
                    .foregroundColor(Color.brandPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled((selectedImage == nil && selectedVideoURL == nil) || isUploading)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task { await loadMedia(from: newItem) }
            }
            .interactiveDismissDisabled(isUploading)
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView { image in
                    selectedImage = image
                    selectedVideoURL = nil
                    isVideo = false
                }
            }
            .fullScreenCover(isPresented: $showVideoRecorder) {
                VineRecorderView(maxSeconds: 60) { url, thumbnail in
                    selectedVideoURL = url
                    selectedImage = thumbnail
                    isVideo = true
                }
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingMedia = true
        errorMessage = nil
        selectedImage = nil
        selectedVideoURL = nil
        isVideo = false

        // Try video first
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            let thumbnail = await generateThumbnail(from: movie.url)
            selectedImage = thumbnail
            selectedVideoURL = movie.url
            isVideo = true
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

    private func uploadStory() async {
        isUploading = true
        errorMessage = nil

        do {
            let mediaItem: MediaItem
            if isVideo, let videoURL = selectedVideoURL, let thumbnail = selectedImage {
                mediaItem = .video(videoURL, thumbnail)
            } else if let image = selectedImage {
                mediaItem = .image(image)
            } else {
                errorMessage = "No media selected."
                isUploading = false
                return
            }

            let mediaIds = try await uploadService.uploadMedia([mediaItem])
            guard let mediaId = mediaIds.first else {
                errorMessage = "Upload failed — no media ID returned."
                isUploading = false
                return
            }

            try await APIClient.shared.requestVoid(.createStory(mediaId: mediaId))

            NotificationCenter.default.post(name: .didCreateStory, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }
}

// MARK: - Video Preview
// Note: VideoTransferable is defined in CreatePostView.swift and reused here

private struct StoryVideoPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
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
    }
}
