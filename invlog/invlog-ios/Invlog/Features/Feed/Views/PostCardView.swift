import SwiftUI
import NukeUI

struct PostCardView: View {
    let post: Post
    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(post: Post) {
        self.post = post
        _isLiked = State(initialValue: post.isLikedByMe ?? false)
        _likeCount = State(initialValue: post.likeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author Header
            HStack(spacing: 10) {
                LazyImage(url: post.author?.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.displayName ?? post.author?.username ?? "Unknown")
                        .font(.subheadline.bold())

                    if let restaurant = post.restaurant {
                        NavigationLink(value: restaurant) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2")
                                    .font(.caption2)
                                Text(restaurant.name)
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                        .accessibilityLabel("At \(restaurant.name), tap to view restaurant")
                    } else if let locationName = post.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(locationName)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .lineLimit(4)
            }

            // Rating
            if let rating = post.rating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= rating ? .orange : .secondary)
                    }
                }
                .accessibilityLabel("\(rating) out of 5 stars")
            }

            // Media
            if let media = post.media, let firstMedia = media.first {
                if firstMedia.mediaType == "video", let videoUrl = URL(string: firstMedia.url) {
                    AutoPlayVideoView(
                        url: videoUrl,
                        thumbnailUrl: URL(string: firstMedia.thumbnailUrl ?? firstMedia.url),
                        blurhash: firstMedia.blurhash
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Post video")
                } else {
                    LazyImage(url: URL(string: firstMedia.mediumUrl ?? firstMedia.url)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if let blurhash = firstMedia.blurhash {
                            BlurhashView(blurhash: blurhash)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Post photo")
                }

                if media.count > 1 {
                    Text("+\(media.count - 1) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if firstMedia.mediaType == "video", let duration = firstMedia.durationSecs {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text(String(format: "0:%02d", Int(duration)))
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Actions
            HStack(spacing: 24) {
                // Like
                Button {
                    toggleLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likeCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isLiked ? "Unlike post, \(likeCount) likes" : "Like post, \(likeCount) likes")

                // Comments — tap navigates to post detail (via parent NavigationLink)
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.accentColor)
                    Text(post.commentCount > 0 ? "\(post.commentCount)" : "Comment")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(post.commentCount > 0 ? "\(post.commentCount) comments, tap to view" : "Add a comment")

                Spacer()
            }
        }
        .padding(.vertical, 4)
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
                // Revert on failure
                isLiked = wasLiked
                likeCount = post.likeCount
            }
        }
    }
}
