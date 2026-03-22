import SwiftUI
import Nuke
@preconcurrency import NukeUI

struct PostDetailView: View {
    let postId: String
    @State private var post: Post?
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var navigateToMention: String? = nil
    @State private var showStickerPicker = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Color.brandTextTertiary)
                    Text("Couldn't load post")
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                    Button("Try Again") {
                        Task { await loadPost(); await loadComments() }
                    }
                    .buttonStyle(InvlogAccentButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PostCardView(post: post)
                            .padding(.horizontal)

                        Rectangle().fill(Color.brandBorder).frame(height: 0.5)

                        // Comments Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Comments")
                                .font(InvlogTheme.heading(16, weight: .bold))
                                .foregroundColor(Color.brandText)
                                .padding(.horizontal)

                            if comments.isEmpty {
                                Text("No comments yet")
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(Color.brandTextSecondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(comments) { comment in
                                    CommentRowView(comment: comment, onMentionTap: { username in
                                        navigateToMention = username
                                    })
                                        .padding(.horizontal)
                                    Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }

                // Comment Input
                HStack(spacing: 8) {
                    Button {
                        showStickerPicker = true
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 22))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .frame(minWidth: 36, minHeight: 36)

                    MentionableTextField(
                        text: $newComment,
                        placeholder: "Add a comment...",
                        axis: .horizontal,
                        lineLimit: 1...3
                    )
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
                .padding()
                .background(Color.brandCard)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                }
                .sheet(isPresented: $showStickerPicker) {
                    StickerPickerView { sticker in
                        Task { await submitStickerComment(sticker) }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let username = navigateToMention {
                        ProfileView(userId: username)
                    }
                },
                isActive: Binding(
                    get: { navigateToMention != nil },
                    set: { if !$0 { navigateToMention = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
        .task {
            await loadPost()
            await loadComments()
        }
    }

    private func loadPost() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .postDetail(id: postId),
                responseType: Post.self
            )
            post = data
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadComments() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .comments(postId: postId, page: 1, perPage: 50),
                responseType: [Comment].self
            )
            comments = data
        } catch {
            // Non-blocking error for comments
        }
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
            comments.insert(comment, at: 0)
        } catch {
            newComment = content
        }
    }

    private func submitStickerComment(_ sticker: GiphySticker) async {
        let content = "[sticker:\(sticker.previewUrl.absoluteString)]"
        do {
            let (comment, _) = try await APIClient.shared.requestWrapped(
                .createComment(postId: postId, content: content, parentId: nil),
                responseType: Comment.self
            )
            comments.insert(comment, at: 0)
        } catch {
            // Silent fail
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    var onMentionTap: ((String) -> Void)? = nil
    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(comment: Comment, onMentionTap: ((String) -> Void)? = nil) {
        self.comment = comment
        self.onMentionTap = onMentionTap
        _isLiked = State(initialValue: comment.isLikedByMe ?? false)
        _likeCount = State(initialValue: comment.likeCount)
    }

    /// Check if comment is a sticker (format: [sticker:URL])
    private var stickerURL: URL? {
        let content = comment.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.hasPrefix("[sticker:"), content.hasSuffix("]") else { return nil }
        let urlStr = String(content.dropFirst(9).dropLast(1))
        return URL(string: urlStr)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            LazyImage(url: comment.author?.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author?.username ?? "Unknown")
                        .font(InvlogTheme.body(13, weight: .bold))
                        .foregroundColor(Color.brandText)
                    Spacer()
                    Text(comment.createdAt, style: .relative)
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextTertiary)
                }

                if let stickerURL {
                    AnimatedGIFView(url: stickerURL)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    MentionText(
                        content: comment.content,
                        font: InvlogTheme.body(14),
                        color: Color.brandText,
                        mentionColor: Color.brandPrimary,
                        onMentionTap: onMentionTap
                    )
                }

                // Like button
                Button {
                    toggleCommentLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(isLiked ? .red : Color.brandTextTertiary)
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(InvlogTheme.caption(11))
                                .foregroundColor(Color.brandTextTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleCommentLike() {
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        Task {
            do {
                if isLiked {
                    try await APIClient.shared.requestVoid(.likeComment(id: comment.id))
                } else {
                    try await APIClient.shared.requestVoid(.unlikeComment(id: comment.id))
                }
            } catch {
                isLiked = wasLiked
                likeCount += wasLiked ? 1 : -1
            }
        }
    }
}

// MARK: - Post Stats Sheet

struct PostStatsSheet: View {
    let post: Post
    let likeCount: Int
    let commentCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 32) {
                    statItem(value: "\(likeCount)", label: "Likes", icon: "heart.fill")
                    statItem(value: "\(commentCount)", label: "Comments", icon: "bubble.right.fill")
                }
                .padding(.vertical, 24)

                Divider()

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 36))
                        .foregroundColor(Color.brandTextTertiary)
                    Text("Detailed analytics coming soon")
                        .font(InvlogTheme.body(14, weight: .medium))
                        .foregroundColor(Color.brandTextSecondary)
                }

                Spacer()
            }
            .invlogScreenBackground()
            .navigationTitle("Post Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Color.brandText)
                    }
                }
            }
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
}
