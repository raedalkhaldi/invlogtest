import SwiftUI
import PhotosUI
import AVFoundation

struct VideoTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "video_\(UUID().uuidString).mp4"
            let destination = tempDir.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var rating: Int?
    @State private var isSubmitting = false
    @State private var showDiscardAlert = false
    @State private var showPlacePicker = false
    @State private var selectedPlace: SelectedPlace?
    @StateObject private var uploadService = MediaUploadService()
    @StateObject private var locationManager = LocationManager()
    @State private var errorMessage: String?

    private var hasContent: Bool {
        selectedPlace != nil && (!content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Text Input
                TextField("Share your experience...", text: $content, axis: .vertical)
                    .font(.body)
                    .lineLimit(5...10)
                    .padding()
                    .accessibilityLabel("Post content")

                // Photo Picker (PHPicker — no permission needed per HIG)
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(selectedImages.isEmpty ? "Add Photos or Videos" : "\(selectedImages.count) selected")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                .accessibilityLabel("Add photos or videos")

                // Selected Images Preview with Upload Status
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    // Upload status overlay
                                    if let state = uploadService.states[index] {
                                        uploadOverlay(for: state)
                                    }
                                }
                                .accessibilityLabel("Selected photo \(index + 1)")
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Overall progress bar
                    if isSubmitting {
                        ProgressView(value: uploadService.overallProgress)
                            .padding(.horizontal)
                            .accessibilityLabel("Upload progress \(Int(uploadService.overallProgress * 100)) percent")
                    }
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = rating == star ? nil : star
                            } label: {
                                Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor((rating ?? 0) >= star ? .orange : .secondary)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }
                }
                .padding(.horizontal)

                // Place Tag (MKLocalSearch)
                Button {
                    showPlacePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)

                        if let place = selectedPlace {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            Text("Select Place *")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(minHeight: 44)
                .padding(.horizontal)
                .accessibilityLabel(selectedPlace != nil ? "Place: \(selectedPlace!.name). Tap to change." : "Add a place")

                // Location status
                if locationManager.location != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Location detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showPlacePicker) {
            PlacePickerView(selectedPlace: $selectedPlace)
        }
        .navigationTitle("Check In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasContent {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Check In") {
                    Task { await submitPost() }
                }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!hasContent || isSubmitting)
            }
        }
        .alert("Discard Check-in?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your check-in will be lost if you go back.")
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                selectedImages = []
                mediaItems = []
                for item in newItems {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        // Video item
                        if let video = try? await item.loadTransferable(type: VideoTransferable.self) {
                            let thumbnail = await generateThumbnail(for: video.url)
                            let thumbImage = thumbnail ?? UIImage(systemName: "video.fill")!
                            selectedImages.append(thumbImage)
                            mediaItems.append(.video(video.url, thumbImage))
                        }
                    } else {
                        // Image item
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                            mediaItems.append(.image(image))
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasContent)
        .onAppear {
            let status = locationManager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
    }

    private func submitPost() async {
        isSubmitting = true
        errorMessage = nil

        do {
            // 1. Upload media first (if any)
            var mediaIds: [String] = []
            if !mediaItems.isEmpty {
                mediaIds = try await uploadService.uploadMedia(mediaItems)
            }

            // 2. Ensure we have a restaurantId — auto-create if place came from Apple Maps
            let lat = selectedPlace?.latitude ?? locationManager.location?.latitude
            let lng = selectedPlace?.longitude ?? locationManager.location?.longitude
            let locName = selectedPlace?.name
            let locAddress = selectedPlace?.address

            var restaurantId = selectedPlace?.restaurantId
            if restaurantId == nil, let place = selectedPlace {
                let (restaurant, _) = try await APIClient.shared.requestWrapped(
                    .createRestaurant(data: [
                        "name": place.name,
                        "latitude": place.latitude,
                        "longitude": place.longitude,
                        "addressLine1": place.address,
                    ]),
                    responseType: Restaurant.self
                )
                restaurantId = restaurant.id
            }

            // 3. Create post
            try await APIClient.shared.requestVoid(
                .createPost(
                    content: content.isEmpty ? nil : content,
                    mediaIds: mediaIds,
                    restaurantId: restaurantId,
                    rating: rating,
                    latitude: lat,
                    longitude: lng,
                    locationName: locName,
                    locationAddress: locAddress
                )
            )

            NotificationCenter.default.post(name: .didCreatePost, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    @ViewBuilder
    private func uploadOverlay(for state: MediaUploadService.UploadState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .compressing:
            uploadStatusBadge(icon: "arrow.trianglehead.2.clockwise", color: .blue)
        case .uploading(let progress):
            ZStack {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                CircularProgressView(progress: progress)
                    .frame(width: 40, height: 40)
            }
        case .processing:
            uploadStatusBadge(icon: "gearshape.2", color: .orange)
        case .completed:
            uploadStatusBadge(icon: "checkmark.circle.fill", color: .green)
        case .failed:
            uploadStatusBadge(icon: "exclamationmark.triangle.fill", color: .red)
        }
    }

    private func uploadStatusBadge(icon: String, color: Color) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
        }
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
