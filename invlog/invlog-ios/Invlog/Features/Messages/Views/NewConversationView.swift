import SwiftUI
import NukeUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var selectedConversation: Conversation?

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
                } else {
                    List(searchResults) { user in
                        Button {
                            startConversation(with: user)
                        } label: {
                            HStack(spacing: 12) {
                                LazyImage(url: user.avatarUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName ?? user.username)
                                        .font(.subheadline.bold())
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .listStyle(.plain)
                }
            }
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
            .navigationDestination(item: $selectedConversation) { conversation in
                MessageThreadView(
                    conversationId: conversation.id,
                    otherUser: conversation.otherUser
                )
            }
        }
    }

    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            let results: SearchResponse = try await APIClient.shared.request(
                .search(query: trimmed, type: "users", lat: nil, lng: nil)
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
                let conversation: Conversation = try await APIClient.shared.request(
                    .startConversation(userId: user.id)
                )
                selectedConversation = conversation
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
