import SwiftUI
import NukeUI

struct FollowListDestination: Hashable {
    let userId: String
    let mode: FollowersListView.Mode
}

struct CheckInListDestination: Hashable {
    let userId: String
}

struct ProfileView: View {
    let userId: String? // nil = current user
    @EnvironmentObject private var appState: AppState
    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var error: String?
    @State private var messageConversation: Conversation?
    @State private var navigateToMessages = false

    private var isCurrentUser: Bool { userId == nil }

    var body: some View {
        ScrollView {
            if let user {
                VStack(spacing: 0) {
                    // Profile Header
                    ProfileHeaderView(
                        user: user,
                        isCurrentUser: isCurrentUser,
                        onMessageTapped: { conversation in
                            messageConversation = conversation
                            navigateToMessages = true
                        }
                    )

                    Divider()

                    // Posts Grid
                    LazyVStack(spacing: 1) {
                        ForEach(posts) { post in
                            NavigationLink(value: post) {
                                PostCardView(post: post)
                                    .padding()
                            }
                            Divider()
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if let error {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Retry",
                    buttonAction: { Task { await loadProfile() } }
                )
                .padding(.top, 60)
            }
        }
        .refreshable {
            await loadProfile()
        }
        .navigationTitle(user?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .navigationDestination(for: FollowListDestination.self) { dest in
            FollowersListView(userId: dest.userId, mode: dest.mode)
        }
        .navigationDestination(for: CheckInListDestination.self) { dest in
            CheckInHistoryView(mode: .user, id: dest.userId)
        }
        .navigationDestination(for: User.self) { user in
            ProfileView(userId: user.username)
        }
        .sheet(isPresented: $navigateToMessages) {
            if let conversation = messageConversation, let user {
                NavigationStack {
                    MessageThreadView(
                        conversationId: conversation.id,
                        otherUser: ConversationUser(
                            id: user.id,
                            username: user.username,
                            displayName: user.displayName,
                            avatarUrl: user.avatarUrl,
                            isVerified: user.isVerified
                        )
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { navigateToMessages = false }
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
                .environmentObject(appState)
            }
        }
        .toolbar {
            if isCurrentUser {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            await loadProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreatePost)) { _ in
            Task { await loadProfile() }
        }
    }

    private func loadProfile() async {
        error = nil
        do {
            if isCurrentUser {
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .currentUser,
                    responseType: User.self
                )
                user = data
                appState.currentUser = data
            } else if let userId {
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .userProfile(username: userId),
                    responseType: User.self
                )
                user = data
            }

            if let user {
                let (feedResponse, _) = try await APIClient.shared.requestWrapped(
                    .userPosts(userId: user.id, cursor: nil, limit: 20),
                    responseType: FeedResponse.self
                )
                posts = feedResponse.data
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct ProfileHeaderView: View {
    let user: User
    let isCurrentUser: Bool
    var onMessageTapped: ((Conversation) -> Void)?
    @State private var isFollowing: Bool
    @State private var isSendingMessage = false

    init(user: User, isCurrentUser: Bool, onMessageTapped: ((Conversation) -> Void)? = nil) {
        self.user = user
        self.isCurrentUser = isCurrentUser
        self.onMessageTapped = onMessageTapped
        _isFollowing = State(initialValue: user.isFollowedByMe ?? false)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            LazyImage(url: user.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .accessibilityLabel("\(user.displayName ?? user.username)'s profile picture")

            // Name
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(.title2.bold())
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .accessibilityLabel("Verified")
                    }
                }

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            // Stats
            HStack(spacing: 32) {
                StatView(count: user.postCount, label: "Posts")

                NavigationLink(value: FollowListDestination(userId: user.id, mode: .followers)) {
                    StatView(count: user.followerCount, label: "Followers")
                }
                .buttonStyle(.plain)

                NavigationLink(value: FollowListDestination(userId: user.id, mode: .following)) {
                    StatView(count: user.followingCount, label: "Following")
                }
                .buttonStyle(.plain)
            }

            // Check-ins link
            NavigationLink(value: CheckInListDestination(userId: user.id)) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.secondary)
                    Text("Check-in History")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("View check-in history")

            // Action Buttons
            if !isCurrentUser {
                HStack(spacing: 12) {
                    profileFollowButton

                    Button {
                        startConversation()
                    } label: {
                        HStack(spacing: 6) {
                            if isSendingMessage {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "envelope")
                            }
                            Text("Message")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSendingMessage)
                    .accessibilityLabel("Message \(user.username)")
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var profileFollowButton: some View {
        let label = Text(isFollowing ? "Following" : "Follow")
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        let accessLabel = isFollowing ? "Unfollow \(user.username)" : "Follow \(user.username)"

        if isFollowing {
            Button { toggleFollow() } label: { label }
                .buttonStyle(.bordered)
                .accessibilityLabel(accessLabel)
        } else {
            Button { toggleFollow() } label: { label }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(accessLabel)
        }
    }

    private func toggleFollow() {
        isFollowing.toggle()
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.requestVoid(.followUser(id: user.id))
                } else {
                    try await APIClient.shared.requestVoid(.unfollowUser(id: user.id))
                }
            } catch {
                isFollowing.toggle() // Revert
            }
        }
    }

    private func startConversation() {
        isSendingMessage = true
        Task {
            do {
                let conversation = try await APIClient.shared.request(
                    .startConversation(userId: user.id),
                    responseType: Conversation.self
                )
                onMessageTapped?(conversation)
            } catch {
                // Handle error silently
            }
            isSendingMessage = false
        }
    }
}

struct StatView: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }
}
