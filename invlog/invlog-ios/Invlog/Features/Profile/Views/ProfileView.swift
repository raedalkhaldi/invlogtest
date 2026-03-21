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
    @State private var showGrid = true

    private var isCurrentUser: Bool { userId == nil }

    var body: some View {
        profileContent
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
                profileMessageSheet(conversation: conversation)
            }
            .toolbar {
                profileToolbar
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
            .onReceive(NotificationCenter.default.publisher(for: .didDeletePost)) { notification in
                if let postId = notification.object as? String {
                    posts.removeAll { $0.id == postId }
                }
            }
    }

    @ViewBuilder
    private var profileContent: some View {
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
                    // Posts header with Grid/List toggle
                    HStack {
                        Text("Posts")
                            .font(InvlogTheme.body(16, weight: .bold))
                            .foregroundColor(Color.brandText)
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showGrid = true }
                            } label: {
                                Image(systemName: "square.grid.3x3.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(showGrid ? Color.brandPrimary : Color.brandTextTertiary)
                                    .frame(width: 36, height: 32)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showGrid = false }
                            } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14))
                                    .foregroundColor(!showGrid ? Color.brandPrimary : Color.brandTextTertiary)
                                    .frame(width: 36, height: 32)
                            }
                        }
                        .background(Color.brandBorder.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, InvlogTheme.Spacing.md)
                    .padding(.top, InvlogTheme.Spacing.md)

                    if showGrid {
                        // Photo grid (3 columns)
                        let gridColumns = [
                            GridItem(.flexible(), spacing: 2),
                            GridItem(.flexible(), spacing: 2),
                            GridItem(.flexible(), spacing: 2)
                        ]
                        LazyVGrid(columns: gridColumns, spacing: 2) {
                            ForEach(posts) { post in
                                NavigationLink(value: post.id) {
                                    if let firstMedia = post.media?.first {
                                        let thumbUrl = firstMedia.thumbnailUrl ?? firstMedia.mediumUrl ?? firstMedia.url
                                        AsyncImage(url: URL(string: thumbUrl)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                Color.brandBackground
                                            }
                                        }
                                        .frame(minHeight: 120)
                                        .clipped()
                                    } else {
                                        Color.brandBackground
                                            .frame(minHeight: 120)
                                            .overlay(
                                                Text(post.content?.prefix(50) ?? "")
                                                    .font(InvlogTheme.caption(11))
                                                    .foregroundColor(Color.brandTextSecondary)
                                                    .padding(8)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, InvlogTheme.Spacing.md)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                    } else {
                        // List view
                        LazyVStack(spacing: InvlogTheme.Spacing.sm) {
                            ForEach(posts) { post in
                                PostCardView(post: post)
                            }
                        }
                        .padding(.horizontal, InvlogTheme.Spacing.md)
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
    }

    @ViewBuilder
    private func profileMessageSheet(conversation: Conversation) -> some View {
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

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
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

    @State private var showEditProfile = false
    @State private var showShareProfile = false

    var body: some View {
        VStack(spacing: 0) {
            // Horizontal profile header (Figma-inspired)
            HStack(alignment: .top, spacing: 16) {
                LazyImage(url: user.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.brandCard, lineWidth: 3))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .accessibilityLabel("\(user.displayName ?? user.username)'s profile picture")

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(user.displayName ?? user.username)
                            .font(InvlogTheme.heading(20, weight: .bold))
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

                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(InvlogTheme.body(13))
                            .foregroundColor(Color.brandText)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }

                    // Level chip
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Lvl 5 Foodie")
                            .font(InvlogTheme.caption(10, weight: .bold))
                    }
                    .foregroundColor(Color.brandSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brandYellowLight)
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.md)

            // Stats
            HStack(spacing: 0) {
                StatView(count: user.postCount, label: "Posts")
                    .frame(maxWidth: .infinity)

                NavigationLink(value: FollowListDestination(userId: user.id, mode: .followers)) {
                    StatView(count: user.followerCount, label: "Followers")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                NavigationLink(value: FollowListDestination(userId: user.id, mode: .following)) {
                    StatView(count: user.followingCount, label: "Following")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, InvlogTheme.Spacing.md)
            .padding(.horizontal, InvlogTheme.Spacing.md)

            // Action Buttons
            if isCurrentUser {
                HStack(spacing: 12) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit Profile")
                            .font(InvlogTheme.body(14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }

                    Button {
                        let url = "https://invlog.app/user/\(user.username)"
                        UIPasteboard.general.string = url
                    } label: {
                        Text("Share Profile")
                            .font(InvlogTheme.body(14, weight: .bold))
                            .foregroundColor(Color.brandText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.brandCard)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                    .stroke(Color.brandBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.md)
            } else {
                HStack(spacing: 12) {
                    profileFollowButton

                    Button {
                        startConversation()
                    } label: {
                        HStack(spacing: 6) {
                            if isSendingMessage {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "envelope")
                            }
                            Text("Message")
                        }
                        .font(InvlogTheme.body(14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.brandCard)
                        .foregroundColor(Color.brandText)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                    }
                    .disabled(isSendingMessage)
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.top, InvlogTheme.Spacing.md)
            }

            // Achievements
            VStack(alignment: .leading, spacing: 8) {
                Text("Achievements")
                    .font(InvlogTheme.body(15, weight: .bold))
                    .foregroundColor(Color.brandText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        achievementBadge(icon: "🏆", title: "Top Reviewer", bg: Color.brandOrangeLight)
                        achievementBadge(icon: "⭐", title: "\(user.postCount) Posts", bg: Color.brandYellowLight)
                        achievementBadge(icon: "🌍", title: "Globe Trotter", bg: Color.brandTealLight)
                        achievementBadge(icon: "🍕", title: "Foodie Expert", bg: Color.brandPurpleLight)
                    }
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.md)

            // Quick links (compact horizontal row)
            HStack(spacing: 8) {
                NavigationLink(value: CheckInListDestination(userId: user.id)) {
                    quickLinkPill(icon: "mappin.and.ellipse", label: "Check-ins", color: Color.brandPrimary)
                }
                .buttonStyle(.plain)

                if isCurrentUser {
                    NavigationLink(value: TripsListDestination()) {
                        quickLinkPill(icon: "map.fill", label: "Trips", color: Color.brandAccent)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: BookmarksView()) {
                        quickLinkPill(icon: "bookmark.fill", label: "Saved", color: Color.brandSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.sm)

            // XP progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("XP Progress")
                        .font(InvlogTheme.caption(11, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    Spacer()
                    Text("750 / 1000 XP")
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.brandBorder)
                        Capsule()
                            .fill(LinearGradient(colors: [Color.brandPrimary, Color.brandSecondary], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * 0.75)
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.top, InvlogTheme.Spacing.sm)
        }
        .padding(.bottom, InvlogTheme.Spacing.md)
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
        }
    }

    private func achievementBadge(icon: String, title: String, bg: Color) -> some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 28))
            Text(title)
                .font(InvlogTheme.caption(10, weight: .semibold))
                .foregroundColor(Color.brandText)
                .lineLimit(1)
        }
        .frame(width: 80, height: 80)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func quickLinkPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(label)
                .font(InvlogTheme.caption(11, weight: .semibold))
                .foregroundColor(Color.brandText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.brandCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.brandBorder, lineWidth: 1))
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
