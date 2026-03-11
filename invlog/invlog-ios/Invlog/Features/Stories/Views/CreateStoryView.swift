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
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.lg))
                        .padding(.horizontal)

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
                        matching: .images
                    ) {
                        Text("Change Photo")
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

                        Text("Select a photo to share with your followers for 24 hours.")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
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
            let mediaIds = try await uploadService.uploadMedia([.image(image)])
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
