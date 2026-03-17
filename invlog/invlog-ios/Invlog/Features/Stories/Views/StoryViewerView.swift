import SwiftUI
@preconcurrency import NukeUI

// MARK: - TikTok-Style Story Feed (Full-Screen Vertical Video)

struct StoryViewerView: View {
    let storyGroups: [StoryGroup]
    let initialGroup: StoryGroup
    @Binding var selectedUsername: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var storiesViewModel: StoriesViewModel

    // Flattened list of all stories for vertical scroll
    @State private var allStories: [(story: Story, group: StoryGroup)] = []
    @State private var currentFlatIndex: Int = 0
    @State private var isDismissing = false
    @State private var showDeleteConfirm = false

    // Long-press to pause
    @State private var isPaused = false

    // Double-tap like
    @State private var showHeartBurst = false
    @State private var heartPosition: CGPoint = .zero
    @State private var heartBurstWorkItem: DispatchWorkItem?

    // Action rail state (local-only — backend has no story like/comment API yet)
    @State private var likedStoryIds: Set<String> = []
    @State private var bookmarkedStoryIds: Set<String> = []
    @State private var storyLikeCounts: [String: Int] = [:]
    @State private var storyCommentCounts: [String: Int] = [:]

    // Sound
    @ObservedObject private var muteManager = VideoMuteManager.shared

    // Vertical snap scroll offset
    @State private var dragOffsetY: CGFloat = 0
    @State private var showComments = false
    @State private var showStats = false

    // Caption expansion
    @State private var isCaptionExpanded = false

    init(storyGroups: [StoryGroup], initialGroup: StoryGroup, selectedUsername: Binding<String?> = .constant(nil), storiesViewModel: StoriesViewModel) {
        self.storyGroups = storyGroups
        self.initialGroup = initialGroup
        self._selectedUsername = selectedUsername
        self.storiesViewModel = storiesViewModel

        // Flatten all stories for a single vertical feed
        var flat: [(Story, StoryGroup)] = []
        var startIdx = 0
        for group in storyGroups {
            for story in group.stories {
                if group.id == initialGroup.id && flat.isEmpty == false && startIdx == 0 {
                    startIdx = flat.count
                }
                flat.append((story, group))
            }
            if group.id == initialGroup.id && startIdx == 0 {
                startIdx = max(0, flat.count - group.stories.count)
            }
        }
        _allStories = State(initialValue: flat)
        _currentFlatIndex = State(initialValue: startIdx)
    }

    private var currentEntry: (story: Story, group: StoryGroup)? {
        guard currentFlatIndex >= 0 && currentFlatIndex < allStories.count else { return nil }
        return allStories[currentFlatIndex]
    }

    private var isOwnStory: Bool {
        guard let entry = currentEntry else { return false }
        return entry.story.authorId == appState.currentUser?.id
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let entry = currentEntry {
                    videoCanvas(entry: entry, size: geo.size)
                        .offset(y: dragOffsetY)

                    overlayUI(entry: entry, size: geo.size)
                        .offset(y: dragOffsetY)
                }
            }
        }
        .ignoresSafeArea()
        .gesture(verticalSwipeGesture)
        .onAppear {
            initializeLikeStates()
            markCurrentAsViewed()
        }
        .onDisappear {
            isDismissing = true
            muteManager.isPaused = false
            isPaused = false
            heartBurstWorkItem?.cancel()
        }
        .statusBarHidden()
        .alert("Delete Vlog", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let entry = currentEntry else { return }
                Task {
                    let success = await storiesViewModel.deleteStory(entry.story.id)
                    if success {
                        allStories.remove(at: currentFlatIndex)
                        if allStories.isEmpty {
                            isDismissing = true
                            dismiss()
                        } else if currentFlatIndex >= allStories.count {
                            currentFlatIndex = allStories.count - 1
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this vlog?")
        }
        .sheet(isPresented: $showComments) {
            VlogReplySheet(
                username: currentEntry?.group.user.username ?? "",
                storyId: currentEntry?.story.id ?? "",
                commentCount: Binding(
                    get: { storyCommentCounts[currentEntry?.story.id ?? ""] ?? 0 },
                    set: { storyCommentCounts[currentEntry?.story.id ?? ""] = $0 }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStats) {
            if let entry = currentEntry {
                VlogStatsSheet(
                    story: entry.story,
                    likeCount: storyLikeCounts[entry.story.id] ?? (entry.story.likeCount ?? 0)
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Initialize like/comment counts from model data

    private func initializeLikeStates() {
        for entry in allStories {
            let sid = entry.story.id
            if entry.story.isLikedByMe == true {
                likedStoryIds.insert(sid)
            }
            if let lc = entry.story.likeCount {
                storyLikeCounts[sid] = lc
            }
            if let cc = entry.story.commentCount {
                storyCommentCounts[sid] = cc
            }
        }
    }

    // MARK: - Video Canvas

    @ViewBuilder
    private func videoCanvas(entry: (story: Story, group: StoryGroup), size: CGSize) -> some View {
        if entry.story.mediaType == "video", let videoUrl = URL(string: entry.story.url), !isDismissing {
            AutoPlayVideoView(
                url: videoUrl,
                thumbnailUrl: entry.story.thumbnailUrl.flatMap { URL(string: $0) },
                blurhash: entry.story.blurhash,
                durationSecs: entry.story.durationSecs
            )
            .id(entry.story.id)
            .frame(width: size.width, height: size.height)
            .clipped()
        } else {
            LazyImage(url: URL(string: entry.story.url)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else if state.isLoading {
                    ZStack {
                        if let blurhash = entry.story.blurhash { BlurhashView(blurhash: blurhash) }
                        ProgressView().tint(.white)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Overlay UI

    private func overlayUI(entry: (story: Story, group: StoryGroup), size: CGSize) -> some View {
        ZStack {
            gestureLayer(size: size)

            if showHeartBurst {
                heartBurstView.position(heartPosition)
            }

            VStack(spacing: 0) {
                topNavBar(entry: entry)
                    .padding(.top, safeAreaTop)

                Spacer()

                HStack(alignment: .bottom, spacing: 0) {
                    metadataOverlay(entry: entry)
                        .frame(maxWidth: size.width * 0.72, alignment: .leading)
                    Spacer(minLength: 4)
                    actionRail(entry: entry)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16 + safeAreaBottom)
            }
        }
    }

    // MARK: - Top Nav Bar

    private func topNavBar(entry: (story: Story, group: StoryGroup)) -> some View {
        HStack {
            Button {
                isDismissing = true
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
            .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Text("\(currentFlatIndex + 1)/\(allStories.count)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)

            Spacer()

            Button { muteManager.toggle() } label: {
                Image(systemName: muteManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.body).foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
            .frame(minWidth: 44, minHeight: 44)

            if isOwnStory {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body).foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Right Action Rail

    private func actionRail(entry: (story: Story, group: StoryGroup)) -> some View {
        let storyId = entry.story.id
        let isLiked = likedStoryIds.contains(storyId)
        let isBookmarked = bookmarkedStoryIds.contains(storyId)
        let likeCount = storyLikeCounts[storyId] ?? (entry.story.likeCount ?? 0)
        let commentCount = storyCommentCounts[storyId] ?? (entry.story.commentCount ?? 0)

        return VStack(spacing: 20) {
            // Creator avatar
            Button {
                selectedUsername = entry.group.user.username
                isDismissing = true
                dismiss()
            } label: {
                ZStack(alignment: .bottom) {
                    LazyImage(url: entry.group.user.avatarUrl) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 36)).foregroundColor(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    if !isOwnStory {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.brandPrimary)
                            .clipShape(Circle())
                            .offset(y: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, isOwnStory ? 0 : 6)

            // Like (local-only — no backend story like API)
            actionRailButton(
                icon: isLiked ? "heart.fill" : "heart",
                iconColor: isLiked ? Color(hex: "FF4D4D") : .white,
                count: likeCount > 0 ? "\(likeCount)" : nil,
                accessibilityLabel: isLiked ? "Unlike" : "Like"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    if isLiked {
                        likedStoryIds.remove(storyId)
                        storyLikeCounts[storyId] = max(0, (storyLikeCounts[storyId] ?? 0) - 1)
                    } else {
                        likedStoryIds.insert(storyId)
                        storyLikeCounts[storyId] = (storyLikeCounts[storyId] ?? 0) + 1
                    }
                }
            }

            // Comment (local-only comments)
            actionRailButton(
                icon: "bubble.right",
                iconColor: .white,
                count: commentCount > 0 ? "\(commentCount)" : nil,
                accessibilityLabel: "Comments"
            ) {
                showComments = true
            }

            // Stats (views count — taps to show stats)
            actionRailButton(
                icon: "chart.bar",
                iconColor: .white,
                count: entry.story.viewCount > 0 ? "\(entry.story.viewCount)" : nil,
                accessibilityLabel: "Stats"
            ) {
                showStats = true
            }

            // Bookmark
            actionRailButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                iconColor: isBookmarked ? Color.brandSecondary : .white,
                count: nil,
                accessibilityLabel: isBookmarked ? "Remove bookmark" : "Bookmark"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    if isBookmarked {
                        bookmarkedStoryIds.remove(storyId)
                    } else {
                        bookmarkedStoryIds.insert(storyId)
                    }
                }
            }

            // Share
            actionRailButton(
                icon: "arrowshape.turn.up.right",
                iconColor: .white,
                count: nil,
                accessibilityLabel: "Share"
            ) {
                shareStory(entry: entry)
            }
        }
    }

    private func actionRailButton(icon: String, iconColor: Color, count: String?, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                if let count = count {
                    Text(count)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .frame(width: 50).frame(minHeight: 44)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Bottom-Left Metadata

    private func metadataOverlay(entry: (story: Story, group: StoryGroup)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                selectedUsername = entry.group.user.username
                isDismissing = true
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("@\(entry.group.user.username ?? "")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                    if entry.group.user.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13)).foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            if let caption = entry.story.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14)).foregroundColor(.white)
                    .lineLimit(isCaptionExpanded ? nil : 2)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .onTapGesture { withAnimation { isCaptionExpanded.toggle() } }
            }

            if let locationName = entry.story.locationName, !locationName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 12))
                    Text(locationName).font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }

            Text(entry.story.createdAt, style: .relative)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Gesture Layer

    private func gestureLayer(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                heartPosition = location
                triggerHeartBurst()
                if let entry = currentEntry {
                    let storyId = entry.story.id
                    if !likedStoryIds.contains(storyId) {
                        likedStoryIds.insert(storyId)
                        storyLikeCounts[storyId] = (storyLikeCounts[storyId] ?? 0) + 1
                    }
                }
            }
            .onTapGesture(count: 1) { location in
                if location.x < size.width * 0.35 {
                    goToPrevious()
                } else if location.x > size.width * 0.65 {
                    goToNext()
                }
            }
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                isPaused = pressing
                muteManager.isPaused = pressing
            }, perform: {})
    }

    // MARK: - Heart Burst

    private var heartBurstView: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat.random(in: 24...48)))
                    .foregroundColor(Color(hex: "FF4D4D"))
                    .opacity(showHeartBurst ? 0 : 1)
                    .scaleEffect(showHeartBurst ? 1.5 : 0.5)
                    .offset(
                        x: showHeartBurst ? CGFloat.random(in: -60...60) : 0,
                        y: showHeartBurst ? CGFloat.random(in: -80...(-20)) : 0
                    )
                    .rotationEffect(.degrees(Double.random(in: -30...30)))
                    .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.05), value: showHeartBurst)
            }
        }
    }

    private func triggerHeartBurst() {
        heartBurstWorkItem?.cancel()
        showHeartBurst = false
        DispatchQueue.main.async { withAnimation { showHeartBurst = true } }
        let workItem = DispatchWorkItem { [self] in showHeartBurst = false }
        heartBurstWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    // MARK: - Vertical Swipe (Snap Scroll + Dismiss)

    private var verticalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffsetY = value.translation.height
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if value.translation.height < -threshold && abs(value.translation.height) > abs(value.translation.width) {
                    withAnimation(.easeInOut(duration: 0.3)) { dragOffsetY = -UIScreen.main.bounds.height }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        goToNext()
                        dragOffsetY = 0
                    }
                } else if value.translation.height > threshold && abs(value.translation.height) > abs(value.translation.width) {
                    withAnimation(.easeInOut(duration: 0.3)) { dragOffsetY = UIScreen.main.bounds.height }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isDismissing = true
                        dismiss()
                    }
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) { dragOffsetY = 0 }
            }
    }

    // MARK: - Navigation

    private func goToNext() {
        if currentFlatIndex < allStories.count - 1 {
            currentFlatIndex += 1
            isCaptionExpanded = false
            markCurrentAsViewed()
        } else {
            isDismissing = true
            dismiss()
        }
    }

    private func goToPrevious() {
        if currentFlatIndex > 0 {
            currentFlatIndex -= 1
            isCaptionExpanded = false
        }
    }

    private func markCurrentAsViewed() {
        guard let entry = currentEntry else { return }
        Task { try? await APIClient.shared.requestVoid(.viewStory(id: entry.story.id)) }
    }

    private func shareStory(entry: (story: Story, group: StoryGroup)) {
        guard let url = URL(string: entry.story.url) else { return }
        let text = "Check out this vlog by @\(entry.group.user.username ?? "")!"
        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0
    }
    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Vlog Stats Sheet (View Count + Like Count)

struct VlogStatsSheet: View {
    let story: Story
    let likeCount: Int

    @Environment(\.dismiss) private var dismiss
    @State private var viewers: [User] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats summary
                HStack(spacing: 32) {
                    statItem(value: "\(story.viewCount)", label: "Views", icon: "eye.fill")
                    statItem(value: "\(likeCount)", label: "Likes", icon: "heart.fill")
                    statItem(value: "\(story.commentCount ?? 0)", label: "Comments", icon: "bubble.right.fill")
                }
                .padding(.vertical, 20)

                Divider()

                // Viewers list
                if isLoading {
                    Spacer()
                    ProgressView().tint(Color.brandPrimary)
                    Spacer()
                } else if viewers.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.system(size: 36))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No viewers yet")
                            .font(InvlogTheme.body(15, weight: .semibold))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    Spacer()
                } else {
                    List {
                        Section {
                            ForEach(viewers) { user in
                                NavigationLink(value: user) {
                                    FollowableUserRowView(user: user)
                                }
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Viewers")
                                .font(InvlogTheme.body(13, weight: .semibold))
                                .foregroundColor(Color.brandTextSecondary)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .invlogScreenBackground()
            .navigationTitle("Vlog Stats")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: User.self) { user in
                ProfileView(userId: user.username)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Color.brandText)
                    }
                }
            }
            .task { await loadViewers() }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.brandPrimary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.brandText)
            Text(label)
                .font(InvlogTheme.caption(12))
                .foregroundColor(Color.brandTextSecondary)
        }
    }

    private func loadViewers() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .storyViewers(id: story.id),
                responseType: [User].self
            )
            viewers = data
        } catch {
            // silent
        }
        isLoading = false
    }
}

// MARK: - Vlog Reply / Comments Sheet (local-only — backend has no story comment API)

struct VlogReplySheet: View {
    let username: String
    let storyId: String
    @Binding var commentCount: Int

    @EnvironmentObject private var appState: AppState
    @State private var replyText = ""
    @State private var comments: [Comment] = []
    @State private var isLoading = false // No API to load from
    @State private var isSending = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No comments yet")
                            .font(InvlogTheme.body(15, weight: .semibold))
                            .foregroundColor(Color.brandTextSecondary)
                        Text("Be the first to comment on @\(username)'s vlog")
                            .font(InvlogTheme.caption(13))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in
                                CommentRowView(comment: comment)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .contextMenu {
                                        if comment.authorId == appState.currentUser?.id {
                                            Button(role: .destructive) {
                                                comments.removeAll { $0.id == comment.id }
                                                commentCount = comments.count
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                Divider()

                // Reply input with mention support
                HStack(spacing: 10) {
                    MentionableTextField(
                        text: $replyText,
                        placeholder: "Reply to @\(username)...",
                        lineLimit: 1...3,
                        foregroundColor: Color.brandText
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.brandCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.brandBorder, lineWidth: 1))
                    .focused($isFocused)

                    if !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            addLocalComment()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.body)
                                .foregroundColor(Color.brandPrimary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.2), value: replyText.isEmpty)
            }
            .invlogScreenBackground()
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isFocused = true }
        }
    }

    /// Add comment locally (backend has no story comment endpoint yet)
    private func addLocalComment() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        replyText = ""

        let localComment = Comment(
            id: UUID().uuidString,
            postId: storyId,
            authorId: appState.currentUser?.id ?? "",
            author: appState.currentUser,
            parentId: nil,
            content: text,
            likeCount: 0,
            createdAt: Date(),
            isLikedByMe: false
        )
        comments.append(localComment)
        commentCount = comments.count
    }
}

// MARK: - Color hex extension

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
