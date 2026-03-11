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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if selectedImage != nil || selectedVideoURL != nil {
                    // Preview
                    if isVideo, let videoURL = selectedVideoURL {
                        StoryVideoPreview(url: videoURL)
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
                            Text("10s video story")
                                .font(InvlogTheme.caption(12, weight: .semibold))
                        }
                        .foregroundColor(Color.brandAccent)
                    }

                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadService.overallProgress)
                                .tint(Color.brandPrimary)
                                .padding(.horizontal)
                            Text("Uploading story...")
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

                        Text("Add to Your Story")
                            .font(InvlogTheme.heading(20, weight: .bold))
                            .foregroundColor(Color.brandText)

                        Text("Select a photo or video to share with your followers for 24 hours.")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Photo or Video")
                            }
                            .font(InvlogTheme.body(14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.brandPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        }
                        .padding(.horizontal, 48)
                    }

                    Spacer()
                }
            }
            .invlogScreenBackground()
            .navigationTitle("New Story")
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
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        selectedImage = nil
        selectedVideoURL = nil
        isVideo = false

        // Try video first
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            selectedVideoURL = movie.url
            isVideo = true
            // Generate thumbnail
            selectedImage = await generateThumbnail(from: movie.url)
        } else if let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) {
            selectedImage = image
            isVideo = false
        }
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

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "story_video_\(UUID().uuidString).mp4"
            let destination = tempDir.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

// MARK: - Video Preview

private struct StoryVideoPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
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

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
    }
}
