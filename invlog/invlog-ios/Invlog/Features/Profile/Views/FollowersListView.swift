import SwiftUI

struct FollowersListView: View {
    let userId: String
    let mode: Mode

    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = true

    enum Mode: String, Hashable {
        case followers = "Followers"
        case following = "Following"
    }

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "No \(mode.rawValue)",
                    description: mode == .followers
                        ? "No one is following this user yet."
                        : "This user isn't following anyone yet."
                )
            } else {
                List {
                    ForEach(users) { user in
                        NavigationLink(value: user) {
                            FollowableUserRowView(user: user)
                        }
                        .frame(minHeight: 44)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            if user.id == users.last?.id && hasMorePages {
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
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: User.self) { user in
            ProfileView(userId: user.username)
        }
        .task {
            await loadUsers()
        }
    }

    private func loadUsers() async {
        isLoading = true
        do {
            let endpoint: APIEndpoint = mode == .followers
                ? .followers(userId: userId, page: 1, perPage: 20)
                : .following(userId: userId, page: 1, perPage: 20)
            let (data, _) = try await APIClient.shared.requestWrapped(
                endpoint,
                responseType: [User].self
            )
            users = data
            hasMorePages = data.count >= 20
        } catch {
            // silent fail for now
        }
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        do {
            let endpoint: APIEndpoint = mode == .followers
                ? .followers(userId: userId, page: currentPage, perPage: 20)
                : .following(userId: userId, page: currentPage, perPage: 20)
            let (data, _) = try await APIClient.shared.requestWrapped(
                endpoint,
                responseType: [User].self
            )
            users.append(contentsOf: data)
            hasMorePages = data.count >= 20
        } catch {
            currentPage -= 1
        }
    }
}
