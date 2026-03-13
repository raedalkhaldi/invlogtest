import SwiftUI
@preconcurrency import NukeUI

struct PostCardView: View {
    let post: Post
    var onCommentAdded: (() -> Void)?
    var onDeleted: (() -> Void)?
    @EnvironmentObject private var appState: AppState
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var isBookmarked: Bool
    @State private var showShareSheet = false
    @State private var showComments = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    @State private var showBlockConfirm = false
    @State private var isDeleted = false

    private var isOwnPost: Bool {
        post.authorId == appState.currentUser?.id
    }

    init(post: Post, onCommentAdded: (() -> Void)? = nil, onDeleted: (() -> Void)? = nil) {
        self.post = post
        self.onCommentAdded = onCommentAdded
        self.onDeleted = onDeleted
        _isLiked = State(initialValue: post.isLikedByMe ?? false)
        _likeCount = State(initialValue: post.likeCount)
        _commentCount = State(initialValue: post.commentCount)
        _isBookmarked = State(initialValue: post.isBookmarkedByMe ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author Header
            HStack(spacing: 10) {
                NavigationLink(destination: ProfileView(userId: post.author?.username ?? post.authorId)) {
                    LazyImage(url: post.author?.avatarUrl) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color.brandTextTertiary)
                        }
                    }
                    .frame(width: InvlogTheme.Avatar.large, height: InvlogTheme.Avatar.large)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    NavigationLink(destination: ProfileView(userId: post.author?.username ?? post.authorId)) {
                        Text(post.author?.displayName ?? post.author?.username ?? "Unknown")
                            .font(InvlogTheme.body(14, weight: .bold))
                            .foregroundColor(Color.brandText)
                    }
                    .buttonStyle(.plain)

                    if let restaurant = post.restaurant {
                        NavigationLink(value: restaurant) {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(restaurant.name)
                                    .font(InvlogTheme.caption(12, weight: .semibold))
                            }
                            .foregroundColor(Color.brandPrimary)
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                        .accessibilityLabel("At \(restaurant.name), tap to view restaurant")
                    } else if let locationName = post.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(locationName)
                                .font(InvlogTheme.caption(12))
                        }
                        .foregroundColor(Color.brandTextSecondary)
                    }

                    if let tripId = post.tripId, let tripTitle = post.tripTitle {
                        NavigationLink(destination: TripDetailView(tripId: tripId)) {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 9))
                                Text(tripTitle)
                                    .font(InvlogTheme.caption(11, weight: .semibold))
                            }
                            .foregroundColor(Color.brandAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if let visibility = post.visibility, visibility != "public" {
                    Image(systemName: visibility == "followers" ? "person.2.fill" : "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.brandTextTertiary)
                }

                Text(post.createdAt, style: .relative)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextTertiary)

                Menu {
                    if isOwnPost {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block User", systemImage: "slash.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.brandTextSecondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Post options")
            }
            .padding(.horizontal, InvlogTheme.Card.padding)
            .padding(.top, InvlogTheme.Card.padding)
            .padding(.bottom, InvlogTheme.Spacing.xs)

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(InvlogTheme.body(15))
                    .foregroundColor(Color.brandText)
                    .lineLimit(4)
                    .padding(.horizontal, InvlogTheme.Card.padding)
                    .padding(.bottom, InvlogTheme.Spacing.xs)
            }

            // Rating
            if let rating = post.rating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= rating ? Color.brandSecondary : Color.brandTextTertiary)
                    }
                }
                .padding(.horizontal, InvlogTheme.Card.padding)
                .padding(.bottom, InvlogTheme.Spacing.xs)
                .accessibilityLabel("\(rating) out of 5 stars")
            }

            // Media
            if let media = post.media, !media.isEmpty {
                MediaCarouselView(media: media)

                if let firstVideo = media.first(where: { $0.mediaType == "video" }),
                   let duration = firstVideo.durationSecs {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text(String(format: "0:%02d", Int(duration)))
                            .font(InvlogTheme.caption(11))
                    }
                    .foregroundColor(Color.brandTextSecondary)
                    .padding(.horizontal, InvlogTheme.Card.padding)
                }
            }

            // Actions Bar
            HStack(spacing: 0) {
                Button {
                    toggleLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : Color.brandTextSecondary)
                        Text("\(likeCount)")
                            .font(InvlogTheme.caption(13, weight: .semibold))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isLiked ? "Unlike post, \(likeCount) likes" : "Like post, \(likeCount) likes")

                Button {
                    showComments = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text(commentCount > 0 ? "\(commentCount)" : "")
                            .font(InvlogTheme.caption(13, weight: .semibold))
                    }
                    .foregroundColor(Color.brandTextSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(commentCount > 0 ? "\(commentCount) comments" : "Add a comment")

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Color.brandTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Share post")

                Button {
                    toggleBookmark()
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? Color.brandPrimary : Color.brandTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark post")
            }
            .padding(.top, InvlogTheme.Spacing.xs)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.brandBorder).frame(height: 0.5)
            }

            // Inline Comments (first 2)
            if let recentComments = post.recentComments, !recentComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recentComments) { comment in
                        HStack(alignment: .top, spacing: 6) {
                            Text(comment.author?.username ?? "user")
                                .font(InvlogTheme.caption(13, weight: .bold))
                                .foregroundColor(Color.brandText)
                            Text(comment.content)
                                .font(InvlogTheme.caption(13))
                                .foregroundColor(Color.brandText)
                                .lineLimit(2)
                        }
                    }

                    if commentCount > 2 {
                        Button {
                            showComments = true
                        } label: {
                            Text("View all \(commentCount) comments")
                                .font(InvlogTheme.caption(13))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, InvlogTheme.Card.padding)
                .padding(.top, InvlogTheme.Spacing.xs)
                .padding(.bottom, InvlogTheme.Spacing.xs)
            } else if commentCount > 0 {
                Button {
                    showComments = true
                } label: {
                    Text("View \(commentCount == 1 ? "1 comment" : "all \(commentCount) comments")")
                        .font(InvlogTheme.caption(13))
                        .foregroundColor(Color.brandTextSecondary)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, InvlogTheme.Card.padding)
                .padding(.top, InvlogTheme.Spacing.xs)
                .padding(.bottom, InvlogTheme.Spacing.xs)
            }
        }
        .invlogCard()
        .opacity(isDeleted ? 0 : 1)
        .frame(height: isDeleted ? 0 : nil)
        .clipped()
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(items: [shareText])
        }
        .sheet(isPresented: $showComments) {
            CommentsSheetView(postId: post.id, commentCount: $commentCount, onCommentAdded: onCommentAdded)
        }
        .sheet(isPresented: $showEditSheet) {
            EditPostSheet(post: post)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deletePost() }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .alert("Block User?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task {
                    try? await APIClient.shared.requestVoid(.blockUser(id: post.authorId))
                    isDeleted = true
                }
            }
        } message: {
            Text("They won't be able to see your posts, and you won't see theirs.")
        }
    }

    private var shareText: String {
        var text = post.author?.displayName ?? post.author?.username ?? "Someone"
        if let restaurant = post.restaurant {
            text += " at \(restaurant.name)"
        }
        if let content = post.content, !content.isEmpty {
            text += ": \(content)"
        }
        return text
    }

    private func toggleBookmark() {
        let was = isBookmarked
        isBookmarked.toggle()
        Task {
            do {
                if isBookmarked {
                    try await APIClient.shared.requestVoid(.bookmarkPost(id: post.id))
                } else {
                    try await APIClient.shared.requestVoid(.removeBookmark(id: post.id))
                }
            } catch {
                isBookmarked = was
            }
        }
    }

    private func toggleLike() {
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Task {
            do {
                if isLiked {
                    try await APIClient.shared.requestVoid(.likePost(id: post.id))
                } else {
                    try await APIClient.shared.requestVoid(.unlikePost(id: post.id))
                }
            } catch {
                isLiked = wasLiked
                likeCount = post.likeCount
            }
        }
    }

    private func deletePost() async {
        do {
            try await APIClient.shared.requestVoid(.deletePost(id: post.id))
            withAnimation {
                isDeleted = true
            }
            onDeleted?()
        } catch {
            // Delete failed silently
        }
    }
}

// MARK: - Edit Post Sheet

struct EditPostSheet: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var rating: Int?
    @State private var visibility: String
    @State private var removedMediaIds: Set<String> = []
    @State private var isSaving = false

    init(post: Post) {
        self.post = post
        _content = State(initialValue: post.content ?? "")
        _rating = State(initialValue: post.rating)
        _visibility = State(initialValue: post.visibility ?? "public")
    }

    private var remainingMedia: [PostMedia] {
        (post.media ?? []).filter { !removedMediaIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contentField
                    mediaGrid
                    ratingSection
                    visibilitySection
                    Spacer()
                }
            }
            .invlogScreenBackground()
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(InvlogTheme.body(15, weight: .bold))
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(isSaving)
                }
            }
        }
    }

    private var contentField: some View {
        TextField("Share your experience...", text: $content, axis: .vertical)
            .font(InvlogTheme.body(15))
            .lineLimit(5...10)
            .padding()
            .accessibilityLabel("Post content")
    }

    @ViewBuilder
    private var mediaGrid: some View {
        if let media = post.media, !media.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Media")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(Color.brandText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(media) { item in
                            mediaItemView(item)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func mediaItemView(_ item: PostMedia) -> some View {
        let isRemoved = removedMediaIds.contains(item.id)
        return ZStack(alignment: .topTrailing) {
            LazyImage(url: URL(string: item.thumbnailUrl ?? item.mediumUrl ?? item.url)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.brandBackground
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isRemoved ? 0.3 : 1.0)

            Button {
                if isRemoved {
                    removedMediaIds.remove(item.id)
                } else {
                    removedMediaIds.insert(item.id)
                }
            } label: {
                Image(systemName: isRemoved ? "arrow.uturn.backward.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isRemoved ? Color.brandPrimary : .white)
                    .shadow(radius: 2)
            }
            .offset(x: 4, y: -4)
        }
    }

    private var ratingSection: some View {
        HStack(spacing: 4) {
            Text("Rating")
                .font(InvlogTheme.body(14, weight: .semibold))
                .foregroundColor(Color.brandText)
            Spacer()
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = (rating == star) ? nil : star
                } label: {
                    Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor((rating ?? 0) >= star ? Color.brandSecondary : Color.brandTextTertiary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
        .padding(.horizontal)
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who can see this?")
                .font(InvlogTheme.body(14, weight: .semibold))
                .foregroundColor(Color.brandText)

            Picker("Visibility", selection: $visibility) {
                Label("Public", systemImage: "globe").tag("public")
                Label("Followers", systemImage: "person.2.fill").tag("followers")
                Label("Private", systemImage: "lock.fill").tag("private")
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    private func saveChanges() async {
        isSaving = true
        do {
            try await APIClient.shared.requestVoid(
                .updatePost(
                    id: post.id,
                    content: content,
                    rating: rating,
                    visibility: visibility,
                    removeMediaIds: removedMediaIds.isEmpty ? nil : Array(removedMediaIds)
                )
            )
            dismiss()
        } catch {
            // Save failed
        }
        isSaving = false
    }
}

// MARK: - Comments Sheet

struct CommentsSheetView: View {
    let postId: String
    @Binding var commentCount: Int
    var onCommentAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 32))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No comments yet")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                        Text("Be the first to comment")
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in
                                CommentRowView(comment: comment)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .invlogScreenBackground()
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    TextField("Add a comment...", text: $newComment)
                        .font(InvlogTheme.body(15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.brandBorder.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .accessibilityLabel("Write a comment")

                    Button {
                        Task { await submitComment() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.brandTextTertiary : Color.brandPrimary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send comment")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.brandCard)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                }
            }
            .task {
                await loadComments()
            }
        }
    }

    private func loadComments() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .comments(postId: postId, page: 1, perPage: 50),
                responseType: [Comment].self
            )
            comments = data
        } catch {
            // Non-blocking
        }
        isLoading = false
    }

    private func submitComment() async {
        let content = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        newComment = ""

        do {
            let (comment, _) = try await APIClient.shared.requestWrapped(
                .createComment(postId: postId, content: content, parentId: nil),
                responseType: Comment.self
            )
            comments.append(comment)
            commentCount += 1
            onCommentAdded?()
        } catch {
            newComment = content
        }
    }
}
