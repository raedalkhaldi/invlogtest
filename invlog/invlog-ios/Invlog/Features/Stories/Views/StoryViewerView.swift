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

    // Action rail state
    @State private var likedStoryIds: Set<String> = []
    @State private var bookmarkedStoryIds: Set<String> = []
    @State private var storyLikeCounts: [String: Int] = [:]
    @State private var storyCommentCounts: [String: Int] = [:]

    // Sound
    @ObservedObject private var muteManager = VideoMuteManager.shared

    // Vertical snap scroll offset
    @State private var dragOffsetY: CGFloat = 0
    @State private var showComments = false
    @State private var showLikedBy = false

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
                    // Full-screen video canvas (base layer, z-index 0)
                    videoCanvas(entry: entry, size: geo.size)
                        .offset(y: dragOffsetY)

                    // Overlay UI (z-index 10+)
                    overlayUI(entry: entry, size: geo.size)
                        .offset(y: dragOffsetY)
                }
            }
        }
        .ignoresSafeArea()
        .gesture(verticalSwipeGesture)
        .onAppear {
            markCurrentAsViewed()
        }
        .onDisappear {
            isDismissing = true
            // Reset pause state so other videos aren't stuck paused
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
        .sheet(isPresented: $showLikedBy) {
            if let entry = currentEntry {
                LikedBySheet(postId: entry.story.id, isStory: true)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Video Canvas (Base Layer)

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
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else if state.isLoading {
                    ZStack {
                        if let blurhash = entry.story.blurhash {
                            BlurhashView(blurhash: blurhash)
                        }
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
            // Tap / double-tap / long-press gesture layer
            gestureLayer(size: size)

            // Heart burst animation (centered at tap point)
            if showHeartBurst {
                heartBurstView
                    .position(heartPosition)
            }

            VStack(spacing: 0) {
                // Top nav bar (z-index 20) — transparent bg
                topNavBar(entry: entry)
                    .padding(.top, safeAreaTop)

                Spacer()

                // Bottom area: metadata (left) + action rail (right)
                HStack(alignment: .bottom, spacing: 0) {
                    // Bottom-left metadata (z-index 10)
                    metadataOverlay(entry: entry)
                        .frame(maxWidth: size.width * 0.72, alignment: .leading)

                    Spacer(minLength: 4)

                    // Right action rail (z-index 10)
                    actionRail(entry: entry)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16 + safeAreaBottom)
            }
        }
    }

    // MARK: - Top Nav Bar (z-index 20)

    private func topNavBar(entry: (story: Story, group: StoryGroup)) -> some View {
        HStack {
            // Close button
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

            // Story progress indicator (e.g., 3/12)
            Text("\(currentFlatIndex + 1)/\(allStories.count)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)

            Spacer()

            // Mute toggle
            Button {
                muteManager.toggle()
            } label: {
                Image(systemName: muteManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.body)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
            .frame(minWidth: 44, minHeight: 44)

            // Delete (own stories only)
            if isOwnStory {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Right Action Rail (z-index 10)

    private func actionRail(entry: (story: Story, group: StoryGroup)) -> some View {
        let storyId = entry.story.id
        let isLiked = likedStoryIds.contains(storyId)
        let isBookmarked = bookmarkedStoryIds.contains(storyId)
        let likeCount = storyLikeCounts[storyId] ?? entry.story.viewCount
        let commentCount = storyCommentCounts[storyId] ?? 0

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
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    // Follow badge (not own story)
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

            // Like button
            actionRailButton(
                icon: isLiked ? "heart.fill" : "heart",
                iconColor: isLiked ? Color(hex: "FF4D4D") : .white,
                count: likeCount > 0 ? "\(likeCount)" : nil,
                accessibilityLabel: isLiked ? "Unlike" : "Like",
                onLongPress: { showLikedBy = true }
            ) {
                toggleLike(storyId: storyId)
            }

            // Comment button
            actionRailButton(
                icon: "bubble.right",
                iconColor: .white,
                count: commentCount > 0 ? "\(commentCount)" : nil,
                accessibilityLabel: "Comments"
            ) {
                showComments = true
            }

            // Bookmark button
            actionRailButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                iconColor: isBookmarked ? Color.brandSecondary : .white,
                count: nil,
                accessibilityLabel: isBookmarked ? "Remove bookmark" : "Bookmark"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    if isBookmarked {
                        bookmarkedStoryIds.remove(storyId)
                        Task { try? await APIClient.shared.requestVoid(.removeBookmark(id: storyId)) }
                    } else {
                        bookmarkedStoryIds.insert(storyId)
                        Task { try? await APIClient.shared.requestVoid(.bookmarkPost(id: storyId)) }
                    }
                }
            }

            // Share button
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

    private func toggleLike(storyId: String) {
        let isLiked = likedStoryIds.contains(storyId)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            if isLiked {
                likedStoryIds.remove(storyId)
                storyLikeCounts[storyId] = max(0, (storyLikeCounts[storyId] ?? 0) - 1)
            } else {
                likedStoryIds.insert(storyId)
                storyLikeCounts[storyId] = (storyLikeCounts[storyId] ?? 0) + 1
            }
        }
        Task {
            if isLiked {
                try? await APIClient.shared.requestVoid(.unlikeStory(id: storyId))
            } else {
                try? await APIClient.shared.requestVoid(.likeStory(id: storyId))
            }
        }
    }

    private func actionRailButton(icon: String, iconColor: Color, count: String?, accessibilityLabel: String, onLongPress: (() -> Void)? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)

                if let count = count {
                    Button {
                        onLongPress?()
                    } label: {
                        Text(count)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 50)
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Bottom-Left Metadata (z-index 10)

    private func metadataOverlay(entry: (story: Story, group: StoryGroup)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Username
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
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            // Caption
            if let caption = entry.story.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(isCaptionExpanded ? nil : 2)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        withAnimation { isCaptionExpanded.toggle() }
                    }
            }

            // Location
            if let locationName = entry.story.locationName, !locationName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                    Text(locationName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }

            // Time ago + view count
            HStack(spacing: 8) {
                Text(entry.story.createdAt, style: .relative)
                    .font(.system(size: 12))

                if entry.story.viewCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text("\(entry.story.viewCount)")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
            .foregroundColor(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Gesture Layer

    private func gestureLayer(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                // Double-tap to like
                heartPosition = location
                triggerHeartBurst()
                if let entry = currentEntry {
                    let storyId = entry.story.id
                    if !likedStoryIds.contains(storyId) {
                        likedStoryIds.insert(storyId)
                        storyLikeCounts[storyId] = (storyLikeCounts[storyId] ?? 0) + 1
                        Task { try? await APIClient.shared.requestVoid(.likeStory(id: storyId)) }
                    }
                }
            }
            .onTapGesture(count: 1) { location in
                // Tap left half → previous, right half → next
                if location.x < size.width * 0.35 {
                    goToPrevious()
                } else if location.x > size.width * 0.65 {
                    goToNext()
                }
                // Middle area tap does nothing (avoids accidental navigation)
            }
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                isPaused = pressing
                muteManager.isPaused = pressing
            }, perform: {})
    }

    // MARK: - Heart Burst Animation

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
                    .animation(
                        .easeOut(duration: 0.8).delay(Double(i) * 0.05),
                        value: showHeartBurst
                    )
            }
        }
    }

    private func triggerHeartBurst() {
        // Cancel any pending dismiss from a previous double-tap
        heartBurstWorkItem?.cancel()

        showHeartBurst = false
        DispatchQueue.main.async {
            withAnimation {
                showHeartBurst = true
            }
        }

        let workItem = DispatchWorkItem { [self] in
            showHeartBurst = false
        }
        heartBurstWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    // MARK: - Vertical Swipe Gesture (Snap Scroll)

    private var verticalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                // Only handle vertical drags
                if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffsetY = value.translation.height
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100

                if value.translation.height < -threshold && abs(value.translation.height) > abs(value.translation.width) {
                    // Swipe up → next video
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dragOffsetY = -UIScreen.main.bounds.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        goToNext()
                        dragOffsetY = 0
                    }
                } else if value.translation.height > threshold && abs(value.translation.height) > abs(value.translation.width) {
                    // Swipe down → dismiss the viewer
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dragOffsetY = UIScreen.main.bounds.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isDismissing = true
                        dismiss()
                    }
                    return
                }

                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffsetY = 0
                }
            }
    }

    // MARK: - Navigation

    private func goToNext() {
        if currentFlatIndex < allStories.count - 1 {
            currentFlatIndex += 1
            isCaptionExpanded = false
            markCurrentAsViewed()
        } else {
            // End of feed
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
        Task {
            try? await APIClient.shared.requestVoid(.viewStory(id: entry.story.id))
        }
    }

    // MARK: - Share

    private func shareStory(entry: (story: Story, group: StoryGroup)) {
        guard let url = URL(string: entry.story.url) else { return }
        let text = "Check out this vlog by @\(entry.group.user.username ?? "")!"
        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Safe Area Helpers

    private var safeAreaTop: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.windows.first?.safeAreaInsets.top ?? 0
        }
        return 0
    }

    private var safeAreaBottom: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.windows.first?.safeAreaInsets.bottom ?? 0
        }
        return 0
    }
}

// MARK: - Vlog Reply / Comments Sheet

struct VlogReplySheet: View {
    let username: String
    let storyId: String
    @Binding var commentCount: Int

    @EnvironmentObject private var appState: AppState
    @State private var replyText = ""
    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var isSending = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.brandPrimary)
                    Spacer()
                } else if comments.isEmpty {
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
                                                Task { await deleteComment(comment) }
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
                    .overlay(
                        Capsule().stroke(Color.brandBorder, lineWidth: 1)
                    )
                    .focused($isFocused)

                    if !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            Task { await sendReply() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.body)
                                .foregroundColor(Color.brandPrimary)
                        }
                        .disabled(isSending)
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
            .task { await loadComments() }
            .onAppear { isFocused = true }
        }
    }

    private func loadComments() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .storyComments(storyId: storyId, page: 1, perPage: 50),
                responseType: [Comment].self
            )
            comments = data
            commentCount = data.count
        } catch {
            // Non-blocking — show empty state
        }
        isLoading = false
    }

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        replyText = ""

        do {
            let (comment, _) = try await APIClient.shared.requestWrapped(
                .createStoryComment(storyId: storyId, content: text, parentId: nil),
                responseType: Comment.self
            )
            comments.append(comment)
            commentCount = comments.count
        } catch {
            // Restore text on failure
            replyText = text
        }
        isSending = false
    }

    private func deleteComment(_ comment: Comment) async {
        do {
            try await APIClient.shared.requestVoid(.deleteComment(id: comment.id))
            comments.removeAll { $0.id == comment.id }
            commentCount = comments.count
        } catch {
            // Silent fail
        }
    }
}

// MARK: - Color hex extension (for spec tokens)

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
