import SwiftUI

struct LikedBySheet: View {
    let postId: String

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = true

    private let perPage = 30

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && users.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    EmptyStateView(
                        systemImage: "heart",
                        title: "No likes yet",
                        description: "Be the first to like this post."
                    )
                } else {
                    List {
                        ForEach(users) { user in
                            NavigationLink(value: user) {
                                if user.id == appState.currentUser?.id {
                                    FollowableUserRowView(user: user)
                                        .overlay {
                                            // Hide follow button for self
                                            HStack {
                                                Spacer()
                                                Color.clear.frame(width: 0, height: 0)
                                            }
                                        }
                                } else {
                                    FollowableUserRowView(user: user)
                                }
                            }
                            .frame(minHeight: 44)
                            .listRowBackground(Color.clear)
                            .onAppear {
                                if user.id == users.last?.id && hasMorePages && !isLoading {
                                    Task { await loadMore() }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .invlogScreenBackground()
            .navigationTitle("Liked by")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: User.self) { user in
                ProfileView(userId: user.username)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color.brandText)
                    }
                }
            }
            .task {
                await loadLikes()
            }
        }
    }

    private func loadLikes() async {
        isLoading = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .postLikes(id: postId, page: 1, perPage: perPage),
                responseType: [User].self
            )
            users = data
            hasMorePages = data.count >= perPage
        } catch {
            // silent fail
        }
        isLoading = false
    }

    private func loadMore() async {
        isLoading = true
        currentPage += 1
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .postLikes(id: postId, page: currentPage, perPage: perPage),
                responseType: [User].self
            )
            users.append(contentsOf: data)
            hasMorePages = data.count >= perPage
        } catch {
            currentPage -= 1
        }
        isLoading = false
    }
}
