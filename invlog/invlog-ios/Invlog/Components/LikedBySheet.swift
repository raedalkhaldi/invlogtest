import SwiftUI

struct LikedBySheet: View {
    let postId: String

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var users: [User] = []
    @State private var isLoading = false

    // Note: /posts/{id}/likes endpoint doesn't exist on backend yet.
    // This sheet will show empty state until backend adds support.

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
        }
    }
}
