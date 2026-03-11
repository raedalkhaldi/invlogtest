import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isPrivate = false
    @State private var isSaving = false

    var body: some View {
        Form {
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
                .disabled(isSaving)
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

    private func save() async {
        isSaving = true
        do {
            try await APIClient.shared.requestVoid(
                .updateProfile(
                    displayName: displayName.isEmpty ? nil : displayName,
                    bio: bio.isEmpty ? nil : bio,
                    isPrivate: isPrivate
                )
            )
            dismiss()
        } catch {
            // Show error
        }
        isSaving = false
    }
}
