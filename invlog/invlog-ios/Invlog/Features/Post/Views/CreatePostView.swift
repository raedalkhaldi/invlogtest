import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var rating: Int?
    @State private var isSubmitting = false
    @State private var showDiscardAlert = false
    @State private var showRestaurantPicker = false
    @State private var selectedRestaurant: Restaurant?
    @StateObject private var uploadService = MediaUploadService()
    @StateObject private var locationManager = LocationManager()
    @State private var errorMessage: String?

    private var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Text Input
                TextField("What are you eating?", text: $content, axis: .vertical)
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

                // Restaurant Tag
                Button {
                    showRestaurantPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .foregroundColor(.secondary)

                        if let restaurant = selectedRestaurant {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(restaurant.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                                    Text(cuisines.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("Tag a Restaurant")
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
                .accessibilityLabel(selectedRestaurant != nil ? "Tagged restaurant: \(selectedRestaurant!.name). Tap to change." : "Tag a restaurant")

                // Location toggle
                if locationManager.location != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Location will be attached")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showRestaurantPicker) {
            RestaurantPickerView(selectedRestaurant: $selectedRestaurant)
        }
        .navigationTitle("New Post")
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
                Button("Post") {
                    Task { await submitPost() }
                }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!hasContent || isSubmitting)
            }
        }
        .alert("Discard Post?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your post will be lost if you go back.")
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                selectedImages = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
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
            if !selectedImages.isEmpty {
                mediaIds = try await uploadService.uploadImages(selectedImages)
            }

            // 2. Create post with media IDs
            let lat = locationManager.location?.latitude
            let lng = locationManager.location?.longitude
            let locName = selectedRestaurant?.name

            try await APIClient.shared.requestVoid(
                .createPost(
                    content: content.isEmpty ? nil : content,
                    mediaIds: mediaIds,
                    restaurantId: selectedRestaurant?.id,
                    rating: rating,
                    latitude: lat,
                    longitude: lng,
                    locationName: locName
                )
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
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
