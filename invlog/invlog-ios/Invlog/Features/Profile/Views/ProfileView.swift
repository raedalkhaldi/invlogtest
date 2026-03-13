import SwiftUI
@preconcurrency import NukeUI

struct FollowListDestination: Hashable {
    let userId: String
    let mode: FollowersListView.Mode
}

struct CheckInListDestination: Hashable {
    let userId: String
}

struct TripsListDestination: Hashable {}

struct ProfileView: View {
    let userId: String? // nil = current user
    @EnvironmentObject private var appState: AppState
    @State private var user: User?
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var error: String?
    @State private var messageConversation: Conversation?
    @State private var showBlockConfirm = false

    private var isCurrentUser: Bool { userId == nil }

    var body: some View {
        ScrollView {
            if let user {
                VStack(spacing: 0) {
                    ProfileHeaderView(
                        user: user,
                        isCurrentUser: isCurrentUser,
                        onMessageTapped: { conversation in
                            messageConversation = conversation
                        }
                    )

                    // Posts
                    LazyVStack(spacing: InvlogTheme.Spacing.sm) {
                        ForEach(posts) { post in
                            PostCardView(post: post)
                        }
                    }
                    .padding(.horizontal, InvlogTheme.Spacing.md)
                    .padding(.top, InvlogTheme.Spacing.md)
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
        .invlogScreenBackground()
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
        .navigationDestination(for: TripsListDestination.self) { _ in
            MyTripsView()
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(tripId: trip.id)
        }
        .navigationDestination(for: User.self) { user in
            ProfileView(userId: user.username)
        }
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .sheet(item: $messageConversation) { conversation in
            if let user {
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
                            Button("Done") { messageConversation = nil }
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
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Settings")
                }
            } else if let user, user.id != appState.currentUser?.id {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block", systemImage: "slash.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("More options")
                }
            }
        }
        .alert("Block User?", isPresented: $showBlockConfirm) {
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to see your posts or profile, and you won't see theirs.")
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

    @Environment(\.dismiss) private var dismiss

    private func blockUser() async {
        guard let user else { return }
        do {
            try await APIClient.shared.requestVoid(.blockUser(id: user.id))
            dismiss()
        } catch {
            // Block failed silently
        }
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
        VStack(spacing: 0) {
            // Header background
            ZStack {
                Color.brandPrimary.opacity(0.15)
                    .frame(height: 100)

                VStack(spacing: 0) {
                    Spacer()
                    LazyImage(url: user.avatarUrl) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Color.brandTextTertiary)
                        }
                    }
                    .frame(width: InvlogTheme.Avatar.profile, height: InvlogTheme.Avatar.profile)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.brandCard, lineWidth: 3))
                    .offset(y: InvlogTheme.Avatar.profile / 2)
                }
            }
            .frame(height: 100)
            .padding(.bottom, InvlogTheme.Avatar.profile / 2 + InvlogTheme.Spacing.sm)
            .accessibilityLabel("\(user.displayName ?? user.username)'s profile picture")

            // Name & Info
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(InvlogTheme.heading(22, weight: .bold))
                        .foregroundColor(Color.brandText)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .accessibilityLabel("Verified")
                    }
                }

                Text("@\(user.username)")
                    .font(InvlogTheme.caption(13))
                    .foregroundColor(Color.brandTextSecondary)

                // Level chip placeholder
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("Lvl 5 Foodie")
                        .font(InvlogTheme.caption(11, weight: .bold))
                }
                .foregroundColor(Color.brandSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandYellowLight)
                .clipShape(Capsule())

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)

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
            .padding(.top, InvlogTheme.Spacing.md)

            // Check-ins link
            NavigationLink(value: CheckInListDestination(userId: user.id)) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(Color.brandPrimary)
                    Text("Check-in History")
                        .font(InvlogTheme.body(14, weight: .semibold))
                        .foregroundColor(Color.brandText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.brandTextTertiary)
                }
                .padding(InvlogTheme.Spacing.sm)
                .background(Color.brandCard)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.sm)
            .accessibilityLabel("View check-in history")

            // My Trips link
            if isCurrentUser {
                NavigationLink(value: TripsListDestination()) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .foregroundColor(Color.brandAccent)
                        Text("My Trips")
                            .font(InvlogTheme.body(14, weight: .semibold))
                            .foregroundColor(Color.brandText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .padding(InvlogTheme.Spacing.sm)
                    .background(Color.brandCard)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.xxs)
                .accessibilityLabel("View my trips")
            }

            // Saved items (only visible to current user)
            if isCurrentUser {
                NavigationLink(destination: BookmarksView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(Color.brandSecondary)
                        Text("Saved")
                            .font(InvlogTheme.body(14, weight: .semibold))
                            .foregroundColor(Color.brandText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .padding(InvlogTheme.Spacing.sm)
                    .background(Color.brandCard)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.xxs)
                .accessibilityLabel("View saved posts")
            }

            // XP progress placeholder
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("XP Progress")
                        .font(InvlogTheme.caption(11, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    Spacer()
                    Text("750 / 1000 XP")
                        .font(InvlogTheme.caption(11))
                        .foregroundColor(Color.brandTextTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.brandBorder)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color.brandSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.75)
                    }
                }
                .frame(height: 6)
            }
            .padding(InvlogTheme.Spacing.sm)
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.xs)

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
                        .font(InvlogTheme.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.brandCard)
                        .foregroundColor(Color.brandText)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                    }
                    .disabled(isSendingMessage)
                    .accessibilityLabel("Message \(user.username)")
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.md)
            }
        }
        .padding(.bottom, InvlogTheme.Spacing.md)
    }

    @ViewBuilder
    private var profileFollowButton: some View {
        Button { toggleFollow() } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(InvlogTheme.body(14, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isFollowing ? Color.brandCard : Color.brandText)
                .foregroundColor(isFollowing ? Color.brandText : Color.brandBackground)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                        .stroke(isFollowing ? Color.brandBorder : Color.clear, lineWidth: 1)
                )
        }
        .accessibilityLabel(isFollowing ? "Unfollow \(user.username)" : "Follow \(user.username)")
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
                isFollowing.toggle()
            }
        }
    }

    private func startConversation() {
        isSendingMessage = true
        Task {
            do {
                let (conversation, _) = try await APIClient.shared.requestWrapped(
                    .startConversation(userId: user.id),
                    responseType: Conversation.self
                )
                onMessageTapped?(conversation)
            } catch {
                print("Failed to start conversation: \(error)")
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
                .font(InvlogTheme.heading(18, weight: .bold))
                .foregroundColor(Color.brandText)
            Text(label)
                .font(InvlogTheme.caption(11))
                .foregroundColor(Color.brandTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }
}
