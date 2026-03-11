import SwiftUI
import NukeUI

struct InviteCollaboratorView: View {
    @Environment(\.dismiss) private var dismiss

    let tripId: String
    let onInvited: () -> Void

    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedUser: User?
    @State private var selectedRole = "editor"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: InvlogTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.brandTextTertiary)
                TextField("Search by username...", text: $searchText)
                    .font(InvlogTheme.body(15))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        selectedUser = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(InvlogTheme.Spacing.sm)
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.sm)

            if let selectedUser {
                // Selected user + role picker
                VStack(spacing: InvlogTheme.Spacing.md) {
                    // Selected user card
                    HStack(spacing: InvlogTheme.Spacing.sm) {
                        LazyImage(url: selectedUser.avatarUrl) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.brandTextTertiary)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(selectedUser.displayName ?? selectedUser.username)
                                    .font(InvlogTheme.body(14, weight: .bold))
                                    .foregroundColor(Color.brandText)
                                if selectedUser.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("@\(selectedUser.username)")
                                .font(InvlogTheme.caption(12))
                                .foregroundColor(Color.brandTextSecondary)
                        }

                        Spacer()

                        Button {
                            self.selectedUser = nil
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color.brandTextTertiary)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Deselect user")
                    }
                    .padding(InvlogTheme.Spacing.sm)
                    .background(Color.brandOrangeLight)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                            .stroke(Color.brandPrimary, lineWidth: 1)
                    )

                    // Role picker
                    VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                        Text("Role")
                            .font(InvlogTheme.caption(13, weight: .bold))
                            .foregroundColor(Color.brandTextSecondary)

                        HStack(spacing: InvlogTheme.Spacing.sm) {
                            roleOption(
                                icon: "pencil.circle.fill",
                                label: "Editor",
                                subtitle: "Can add & edit stops",
                                value: "editor"
                            )
                            roleOption(
                                icon: "eye.circle.fill",
                                label: "Viewer",
                                subtitle: "Can only view",
                                value: "viewer"
                            )
                        }
                    }

                    // Error / Success
                    if let errorMessage {
                        Text(errorMessage)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(.red)
                    }
                    if let successMessage {
                        Text(successMessage)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandAccent)
                    }

                    // Invite button
                    Button {
                        Task { await invite() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text("Send Invite")
                                .font(InvlogTheme.body(15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.brandPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }
                    .disabled(isSubmitting)
                    .frame(minHeight: 48)
                    .accessibilityLabel("Send invite to \(selectedUser.username) as \(selectedRole)")
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.md)

                Spacer()
            } else if isSearching {
                ProgressView()
                    .padding(.top, 40)
                Spacer()
            } else if !searchResults.isEmpty {
                // Search results list
                List {
                    ForEach(searchResults) { user in
                        Button {
                            selectedUser = user
                            searchResults = []
                        } label: {
                            HStack(spacing: InvlogTheme.Spacing.sm) {
                                LazyImage(url: user.avatarUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(Color.brandTextTertiary)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(user.displayName ?? user.username)
                                            .font(InvlogTheme.body(14, weight: .bold))
                                            .foregroundColor(Color.brandText)
                                        if user.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    Text("@\(user.username)")
                                        .font(InvlogTheme.caption(12))
                                        .foregroundColor(Color.brandTextSecondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color.brandPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel("Select \(user.displayName ?? user.username)")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else if !searchText.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(Color.brandTextTertiary)
                    Text("No users found")
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(Color.brandTextTertiary)
                    Text("Search for a user to invite")
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                    Text("They can help plan and edit your trip")
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Invite Collaborator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .onChange(of: searchText) { _ in
            triggerSearch()
        }
    }

    // MARK: - Role Option

    private func roleOption(icon: String, label: String, subtitle: String, value: String) -> some View {
        Button {
            selectedRole = value
        } label: {
            VStack(spacing: InvlogTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedRole == value ? Color.brandPrimary : Color.brandTextTertiary)
                Text(label)
                    .font(InvlogTheme.body(13, weight: .bold))
                    .foregroundColor(selectedRole == value ? Color.brandText : Color.brandTextSecondary)
                Text(subtitle)
                    .font(InvlogTheme.caption(10))
                    .foregroundColor(Color.brandTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(InvlogTheme.Spacing.sm)
            .background(selectedRole == value ? Color.brandOrangeLight : Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(selectedRole == value ? Color.brandPrimary : Color.brandBorder, lineWidth: selectedRole == value ? 2 : 1)
            )
        }
        .frame(minHeight: 44)
        .accessibilityLabel("\(label) role")
        .accessibilityAddTraits(selectedRole == value ? .isSelected : [])
    }

    // MARK: - Search

    private func triggerSearch() {
        searchTask?.cancel()
        selectedUser = nil
        successMessage = nil
        errorMessage = nil

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            do {
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .search(query: searchText, type: "people", lat: nil, lng: nil),
                    responseType: SearchResults.self
                )
                if !Task.isCancelled {
                    searchResults = data.users
                }
            } catch {
                // Silently handle
            }
            isSearching = false
        }
    }

    // MARK: - Invite

    private func invite() async {
        guard let user = selectedUser else { return }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        do {
            try await APIClient.shared.requestVoid(
                .inviteCollaborator(tripId: tripId, userId: user.id, role: selectedRole)
            )
            successMessage = "\(user.displayName ?? user.username) invited as \(selectedRole)!"
            onInvited()
            // Auto-dismiss after a short delay
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
