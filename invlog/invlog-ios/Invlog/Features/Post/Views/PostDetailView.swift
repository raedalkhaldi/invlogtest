import SwiftUI

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
                        .foregroundColor(.secondary)
                    Text("Couldn't load post")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        Task { await loadPost(); await loadComments() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PostCardView(post: post)
                            .padding(.horizontal)

                        Divider()

                        // Comments Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Comments")
                                .font(.headline)
                                .padding(.horizontal)

                            if comments.isEmpty {
                                Text("No comments yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(comments) { comment in
                                    CommentRowView(comment: comment)
                                        .padding(.horizontal)
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }

                // Comment Input
                HStack(spacing: 8) {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Write a comment")

                    Button {
                        Task { await submitComment() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send comment")
                }
                .padding()
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
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
                .comments(postId: postId, cursor: nil, limit: 50),
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
            newComment = content // Restore on failure
        }
    }
}

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: comment.author?.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author?.username ?? "Unknown")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(comment.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(comment.content)
                    .font(.subheadline)
            }
        }
    }
}
