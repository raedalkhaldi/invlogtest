import SwiftUI
import PhotosUI

struct CreateStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @StateObject private var uploadService = MediaUploadService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = selectedImage {
                    // Preview selected image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadService.overallProgress)
                                .padding(.horizontal)
                            Text("Uploading story...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Change photo button
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images
                    ) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                } else {
                    // Empty state — prompt to select photo
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Add to Your Story")
                            .font(.title3.bold())

                        Text("Select a photo to share with your followers for 24 hours.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Photo")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 48)
                    }

                    Spacer()
                }
            }
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
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(selectedImage == nil || isUploading)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        errorMessage = nil
                    }
                }
            }
            .interactiveDismissDisabled(isUploading)
        }
    }

    private func uploadStory() async {
        guard let image = selectedImage else { return }
        isUploading = true
        errorMessage = nil

        do {
            // 1. Upload image via MediaUploadService
            let mediaIds = try await uploadService.uploadMedia([.image(image)])
            guard let mediaId = mediaIds.first else {
                errorMessage = "Upload failed — no media ID returned."
                isUploading = false
                return
            }

            // 2. Create story via API
            try await APIClient.shared.requestVoid(.createStory(mediaId: mediaId))

            // 3. Notify feed to refresh stories
            NotificationCenter.default.post(name: .didCreateStory, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }
}
