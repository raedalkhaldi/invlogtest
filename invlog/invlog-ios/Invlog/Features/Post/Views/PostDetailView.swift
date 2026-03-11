import SwiftUI
import NukeUI

struct PostDetailView: View {
    let postId: String
    @State private var post: Post?
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = true
    @State private var error: String?

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
                                    CommentRowView(comment: comment)
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
                .padding()
                .background(Color.brandCard)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                }
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
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
}

struct CommentRowView: View {
    let comment: Comment

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

                Text(comment.content)
                    .font(InvlogTheme.body(14))
                    .foregroundColor(Color.brandText)
            }
        }
    }
}
