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

    /// When set, the place is pre-selected. Used when checking in from a restaurant/place profile.
    let preselectedRestaurant: Restaurant?

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
    @State private var showPhotoCapture = false
    @State private var showVineRecorder = false
    @State private var showVideoFilter = false
    @State private var showVideoTrim = false
    @State private var showVideoOverlay = false
    @State private var recordedVideoURL: URL?
    @State private var recordedVideoThumbnail: UIImage?
    @State private var imagesToCrop: [UIImage] = []
    @State private var currentCropIndex = 0
    @State private var showCropView = false
    @State private var visibility = "public"
    @State private var matchingTrips: [Trip] = []
    @State private var selectedTripId: String?

    init(preselectedRestaurant: Restaurant? = nil) {
        self.preselectedRestaurant = preselectedRestaurant
        if let r = preselectedRestaurant {
            _selectedPlace = State(initialValue: SelectedPlace(
                name: r.name,
                address: r.addressLine1 ?? "",
                latitude: r.latitude ?? 0,
                longitude: r.longitude ?? 0,
                restaurantId: r.id
            ))
        }
    }

    private var hasContent: Bool {
        selectedPlace != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                textInputSection
                mediaButtonsSection
                selectedImagesPreview
                errorSection
                ratingSection
                placeTagSection
                locationStatusSection
                visibilitySection
                tripLinkingSection
            }
        }
        .invlogScreenBackground()
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
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
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
        .onChange(of: selectedPlace?.restaurantId) { _ in
            Task { await fetchMatchingTrips() }
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                selectedImages = []
                mediaItems = []
                var newImagesToCrop: [UIImage] = []
                for item in newItems {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        if let video = try? await item.loadTransferable(type: VideoTransferable.self) {
                            let thumbnail = await VideoThumbnailGenerator.generateThumbnail(from: video.url, maxSize: CGSize(width: 512, height: 512))
                            let thumbImage = thumbnail ?? UIImage(systemName: "video.fill")!
                            selectedImages.append(thumbImage)
                            mediaItems.append(.video(video.url, thumbImage))
                        }
                    } else {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            newImagesToCrop.append(image)
                        }
                    }
                }
                if !newImagesToCrop.isEmpty {
                    imagesToCrop = newImagesToCrop
                    currentCropIndex = 0
                    showCropView = true
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoCapture) {
            NavigationStack {
                PhotoCaptureView { capturedImage in
                    showPhotoCapture = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        imagesToCrop = [capturedImage]
                        currentCropIndex = 0
                        showCropView = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showVineRecorder) {
            NavigationStack {
                VineRecorderView { videoURL, thumbnail in
                    recordedVideoURL = videoURL
                    recordedVideoThumbnail = thumbnail
                    showVineRecorder = false
                    // Show filter view after a brief delay to allow dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showVideoFilter = true
                    }
                }
            }
        }
        .sheet(isPresented: $showVideoFilter) {
            if let videoURL = recordedVideoURL, let thumb = recordedVideoThumbnail {
                NavigationStack {
                    VideoFilterView(videoURL: videoURL, thumbnail: thumb) { filteredURL, filteredThumb in
                        recordedVideoURL = filteredURL
                        recordedVideoThumbnail = filteredThumb
                        showVideoFilter = false
                        // Chain to trim view
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showVideoTrim = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showVideoTrim) {
            if let videoURL = recordedVideoURL, let thumb = recordedVideoThumbnail {
                NavigationStack {
                    VideoTrimView(videoURL: videoURL, thumbnail: thumb) { trimmedURL, trimmedThumb in
                        recordedVideoURL = trimmedURL
                        recordedVideoThumbnail = trimmedThumb
                        showVideoTrim = false
                        // Chain to overlay editor
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showVideoOverlay = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showVideoOverlay) {
            if let videoURL = recordedVideoURL, let thumb = recordedVideoThumbnail {
                NavigationStack {
                    VideoOverlayEditorView(
                        videoURL: videoURL,
                        thumbnail: thumb,
                        placeName: selectedPlace?.name,
                        onComplete: { finalURL, finalThumb in
                            mediaItems.append(.video(finalURL, finalThumb))
                            selectedImages.append(finalThumb)
                            showVideoOverlay = false
                            recordedVideoURL = nil
                            recordedVideoThumbnail = nil
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showCropView) {
            imagesToCrop = []
            currentCropIndex = 0
        } content: {
            if currentCropIndex < imagesToCrop.count {
                NavigationStack {
                    ImageCropView(
                        image: imagesToCrop[currentCropIndex],
                        imageNumber: currentCropIndex + 1,
                        totalImages: imagesToCrop.count
                    ) { croppedImage in
                        selectedImages.append(croppedImage)
                        mediaItems.append(.image(croppedImage))
                        if currentCropIndex + 1 < imagesToCrop.count {
                            currentCropIndex += 1
                        } else {
                            showCropView = false
                        }
                    }
                    .id(currentCropIndex)
                }
            }
        }
        .interactiveDismissDisabled(hasContent)
        .onChange(of: mediaItems.count) { _ in
            guard !mediaItems.isEmpty else {
                uploadService.cancelEagerUpload()
                return
            }
            uploadService.startEagerUpload(mediaItems)
        }
        .onAppear {
            let status = locationManager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
    }

    // MARK: - Extracted Sections

    @ViewBuilder
    private var textInputSection: some View {
        MentionableTextField(
            text: $content,
            placeholder: "Share your experience...",
            lineLimit: 5...10
        )
        .font(InvlogTheme.body(15))
        .padding()
        .accessibilityLabel("Post content")
    }

    @ViewBuilder
    private var mediaButtonsSection: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        ) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                Text(selectedImages.isEmpty ? "Add Photos or Videos" : "\(selectedImages.count) selected")
            }
            .font(InvlogTheme.body(14, weight: .semibold))
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
        .padding(.horizontal)
        .accessibilityLabel("Add photos or videos")

        Button {
            showPhotoCapture = true
        } label: {
            HStack {
                Image(systemName: "camera.fill")
                Text("Take Photo")
            }
            .font(InvlogTheme.body(14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandSecondary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
        }
        .padding(.horizontal)
        .accessibilityLabel("Take a photo with camera")

        Button {
            showVineRecorder = true
        } label: {
            HStack {
                Image(systemName: "video.fill")
                Text("Record a Clip")
            }
            .font(InvlogTheme.body(14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
        }
        .padding(.horizontal)
        .accessibilityLabel("Record a short video clip")
    }

    @ViewBuilder
    private var selectedImagesPreview: some View {
        if !selectedImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))

                            if let state = uploadService.states[index] {
                                uploadOverlay(for: state)
                            }
                        }
                        .accessibilityLabel("Selected photo \(index + 1)")
                    }
                }
                .padding(.horizontal)
            }

            if isSubmitting {
                ProgressView(value: uploadService.overallProgress)
                    .tint(Color.brandPrimary)
                    .padding(.horizontal)
                    .accessibilityLabel("Upload progress \(Int(uploadService.overallProgress * 100)) percent")
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(InvlogTheme.caption(12))
                .foregroundColor(.red)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating (optional)")
                .font(InvlogTheme.caption(13))
                .foregroundColor(Color.brandTextSecondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = rating == star ? nil : star
                    } label: {
                        Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor((rating ?? 0) >= star ? Color.brandSecondary : Color.brandTextTertiary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var placeTagSection: some View {
        if preselectedRestaurant != nil, let place = selectedPlace {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                    if !place.address.isEmpty {
                        Text(place.address)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.brandAccent)
            }
            .padding(InvlogTheme.Spacing.sm)
            .background(Color.brandOrangeLight)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(Color.brandPrimary, lineWidth: 1)
            )
            .padding(.horizontal)
            .accessibilityLabel("Checking in at \(place.name)")
        } else {
            Button {
                showPlacePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color.brandPrimary)
                    if let place = selectedPlace {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(InvlogTheme.body(14, weight: .bold))
                                .foregroundColor(Color.brandText)
                            if !place.address.isEmpty {
                                Text(place.address)
                                    .font(InvlogTheme.caption(12))
                                    .foregroundColor(Color.brandTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("Select Place *")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.brandTextTertiary)
                }
                .padding(InvlogTheme.Spacing.sm)
                .background(Color.brandCard)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
            }
            .frame(minHeight: 44)
            .padding(.horizontal)
            .accessibilityLabel(selectedPlace != nil ? "Place: \(selectedPlace!.name). Tap to change." : "Add a place")
        }
    }

    @ViewBuilder
    private var locationStatusSection: some View {
        if locationManager.location != nil {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(Color.brandAccent)
                Text("Location detected")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who can see this?")
                .font(InvlogTheme.caption(13))
                .foregroundColor(Color.brandTextSecondary)

            Picker("Visibility", selection: $visibility) {
                Label("Public", systemImage: "globe").tag("public")
                Label("Followers", systemImage: "person.2.fill").tag("followers")
                Label("Private", systemImage: "lock.fill").tag("private")
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var tripLinkingSection: some View {
        if !matchingTrips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Link to a trip")
                    .font(InvlogTheme.caption(13))
                    .foregroundColor(Color.brandTextSecondary)

                ForEach(matchingTrips) { trip in
                    tripRow(trip)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func tripRow(_ trip: Trip) -> some View {
        let isSelected = selectedTripId == trip.id
        Button {
            selectedTripId = isSelected ? nil : trip.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color.brandPrimary : Color.brandTextTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title)
                        .font(InvlogTheme.body(14, weight: .semibold))
                        .foregroundColor(Color.brandText)
                    Text(trip.status.capitalized)
                        .font(InvlogTheme.caption(11))
                        .foregroundColor(Color.brandTextSecondary)
                }
                Spacer()
                Image(systemName: "map.fill")
                    .font(.caption)
                    .foregroundColor(Color.brandPrimary)
            }
            .padding(InvlogTheme.Spacing.sm)
            .background(isSelected ? Color.brandOrangeLight : Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(isSelected ? Color.brandPrimary : Color.brandBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func submitPost() async {
        isSubmitting = true
        errorMessage = nil

        do {
            var mediaIds: [String] = []
            if !mediaItems.isEmpty {
                mediaIds = try await uploadService.awaitEagerUpload(fallbackItems: mediaItems)
            }

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

            try await APIClient.shared.requestVoid(
                .createPost(
                    content: content.isEmpty ? nil : content,
                    mediaIds: mediaIds,
                    restaurantId: restaurantId,
                    rating: rating,
                    latitude: lat,
                    longitude: lng,
                    locationName: locName,
                    locationAddress: locAddress,
                    visibility: visibility,
                    tripId: selectedTripId
                )
            )

            NotificationCenter.default.post(name: .didCreatePost, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func fetchMatchingTrips() async {
        matchingTrips = []
        selectedTripId = nil
        guard let restaurantId = selectedPlace?.restaurantId else { return }
        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .myTrips(cursor: nil, limit: 50),
                responseType: TripsResponse.self
            )
            // Filter to active trips that have a stop matching this restaurant
            matchingTrips = response.data.filter { trip in
                trip.status == "active" && (trip.stops ?? []).contains { $0.restaurantId == restaurantId }
            }
        } catch {
            // Silently fail — trip linking is optional
        }
    }

    // Uses shared VideoThumbnailGenerator

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
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                CircularProgressView(progress: progress)
                    .frame(width: 40, height: 40)
            }
        case .processing:
            uploadStatusBadge(icon: "gearshape.2", color: Color.brandSecondary)
        case .completed:
            uploadStatusBadge(icon: "checkmark.circle.fill", color: Color.brandAccent)
        case .failed:
            uploadStatusBadge(icon: "exclamationmark.triangle.fill", color: .red)
        }
    }

    private func uploadStatusBadge(icon: String, color: Color) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
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
                .font(InvlogTheme.caption(10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
