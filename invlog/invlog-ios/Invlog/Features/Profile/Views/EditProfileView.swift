import SwiftUI
import PhotosUI
@preconcurrency import NukeUI

struct AvatarPresignResponse: Codable {
    let uploadUrl: String
    let publicUrl: String
    let key: String
}

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isPrivate = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingAvatar = false

    var body: some View {
        Form {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: InvlogTheme.Avatar.profile, height: InvlogTheme.Avatar.profile)
                                    .clipShape(Circle())
                            } else {
                                LazyImage(url: appState.currentUser?.avatarUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(Color.brandTextTertiary)
                                    }
                                }
                                .frame(width: InvlogTheme.Avatar.profile, height: InvlogTheme.Avatar.profile)
                                .clipShape(Circle())
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.brandPrimary)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.brandCard, lineWidth: 2))
                            }
                            .accessibilityLabel("Change profile photo")
                        }

                        if isUploadingAvatar {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Uploading...")
                                    .font(InvlogTheme.caption(12))
                                    .foregroundColor(Color.brandTextSecondary)
                            }
                        } else {
                            Text("Change Photo")
                                .font(InvlogTheme.caption(12))
                                .foregroundColor(Color.brandPrimary)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Display Name") {
                TextField("Display Name", text: $displayName)
                    .font(InvlogTheme.body(15))
                    .accessibilityLabel("Display name")
            }

            Section("Bio") {
                TextField("Tell people about yourself", text: $bio, axis: .vertical)
                    .font(InvlogTheme.body(15))
                    .lineLimit(3...6)
                    .accessibilityLabel("Bio")
            }

            Section("Privacy") {
                Toggle("Private Account", isOn: $isPrivate)
                    .font(InvlogTheme.body(15))
                    .frame(minHeight: 44)
                    .tint(Color.brandPrimary)
                    .accessibilityLabel("Private account")
                    .accessibilityHint("When enabled, only approved followers can see your posts")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .invlogScreenBackground()
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isSaving || isUploadingAvatar)
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await uploadAvatar(image)
                }
            }
        }
        .onAppear {
            if let user = appState.currentUser {
                displayName = user.displayName ?? ""
                bio = user.bio ?? ""
                isPrivate = user.isPrivate
            }
        }
    }

    @State private var uploadedAvatarUrl: String?

    private func uploadAvatar(_ image: UIImage) async {
        isUploadingAvatar = true
        errorMessage = nil

        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Could not process image"
                isUploadingAvatar = false
                return
            }

            // 1. Get presigned URL
            let (presign, _) = try await APIClient.shared.requestWrapped(
                .avatarPresign(contentType: "image/jpeg", fileSize: imageData.count),
                responseType: AvatarPresignResponse.self
            )

            // 2. Upload to S3
            guard let uploadUrl = URL(string: presign.uploadUrl) else {
                errorMessage = "Invalid upload URL"
                isUploadingAvatar = false
                return
            }

            var request = URLRequest(url: uploadUrl)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")

            let (_, response) = try await URLSession.shared.upload(for: request, from: imageData)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Upload failed"
                isUploadingAvatar = false
                return
            }

            uploadedAvatarUrl = presign.publicUrl
        } catch {
            errorMessage = error.localizedDescription
            selectedImage = nil
        }

        isUploadingAvatar = false
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await APIClient.shared.requestVoid(
                .updateProfile(
                    displayName: displayName.isEmpty ? nil : displayName,
                    bio: bio.isEmpty ? nil : bio,
                    isPrivate: isPrivate,
                    avatarUrl: uploadedAvatarUrl
                )
            )
            // Refresh current user data
            if let (user, _) = try? await APIClient.shared.requestWrapped(
                .currentUser,
                responseType: User.self
            ) {
                appState.currentUser = user
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
