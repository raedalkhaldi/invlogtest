import SwiftUI
import NukeUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var selectedConversation: Conversation?
    @State private var navigateToThread = false
    @State private var followedUsers: [User] = []
    @State private var isLoadingFollowed = false

    var body: some View {
        NavigationStack {
            VStack {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        systemImage: "person.slash",
                        title: "No Users Found",
                        description: "Try a different search term."
                    )
                } else if !searchText.isEmpty {
                    userList(users: searchResults)
                } else if isLoadingFollowed {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if !followedUsers.isEmpty {
                    List {
                        Section {
                            ForEach(followedUsers) { user in
                                Button {
                                    startConversation(with: user)
                                } label: {
                                    userRow(user: user)
                                }
                                .frame(minHeight: 44)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Suggested")
                                .font(InvlogTheme.caption(12, weight: .bold))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "No Suggestions",
                        description: "Follow people to see them here, or search for users above."
                    )
                }
            }
            .invlogScreenBackground()
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .searchable(text: $searchText, prompt: "Search users...")
            .onChange(of: searchText) { newValue in
                Task { await search(query: newValue) }
            }
            .navigationDestination(isPresented: $navigateToThread) {
                if let conversation = selectedConversation {
                    MessageThreadView(
                        conversationId: conversation.id,
                        otherUser: conversation.otherUser
                    )
                }
            }
            .task {
                await loadFollowedUsers()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func userList(users: [User]) -> some View {
        List(users) { user in
            Button {
                startConversation(with: user)
            } label: {
                userRow(user: user)
            }
            .frame(minHeight: 44)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func userRow(user: User) -> some View {
        HStack(spacing: 12) {
            LazyImage(url: user.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username)
                    .font(InvlogTheme.body(14, weight: .bold))
                    .foregroundColor(Color.brandText)
                Text("@\(user.username)")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
            }
        }
    }

    // MARK: - Data Loading

    private func loadFollowedUsers() async {
        var currentUserId: String?
        if let user = appState.currentUser {
            currentUserId = user.id
        } else {
            do {
                let (user, _) = try await APIClient.shared.requestWrapped(
                    .currentUser,
                    responseType: User.self
                )
                appState.currentUser = user
                currentUserId = user.id
            } catch {
                return
            }
        }
        guard let userId = currentUserId else { return }
        isLoadingFollowed = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .following(userId: userId, page: 1, perPage: 50),
                responseType: [User].self
            )
            followedUsers = data
        } catch {
            // Handle error silently
        }
        isLoadingFollowed = false
    }

    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            let results = try await APIClient.shared.request(
                .search(query: trimmed, type: "users", lat: nil, lng: nil),
                responseType: SearchResponse.self
            )
            searchResults = results.users ?? []
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    private func startConversation(with user: User) {
        Task {
            do {
                let conversation = try await APIClient.shared.request(
                    .startConversation(userId: user.id),
                    responseType: Conversation.self
                )
                selectedConversation = conversation
                navigateToThread = true
            } catch {
                // Handle error
            }
        }
    }
}

/// Helper model for search results
private struct SearchResponse: Codable {
    let users: [User]?
    let posts: [Post]?
    let restaurants: [Restaurant]?
}
