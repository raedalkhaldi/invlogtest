import SwiftUI
import NukeUI

struct PostCardView: View {
    let post: Post
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isBookmarked: Bool
    @State private var showShareSheet = false

    init(post: Post) {
        self.post = post
        _isLiked = State(initialValue: post.isLikedByMe ?? false)
        _likeCount = State(initialValue: post.likeCount)
        _isBookmarked = State(initialValue: post.isBookmarkedByMe ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author Header
            HStack(spacing: 10) {
                LazyImage(url: post.author?.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: InvlogTheme.Avatar.medium, height: InvlogTheme.Avatar.medium)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.displayName ?? post.author?.username ?? "Unknown")
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)

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
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextTertiary)
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
                    .padding(.horizontal, InvlogTheme.Card.padding)

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

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text(post.commentCount > 0 ? "\(post.commentCount)" : "")
                        .font(InvlogTheme.caption(13, weight: .semibold))
                }
                .foregroundColor(Color.brandTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(post.commentCount > 0 ? "\(post.commentCount) comments" : "Add a comment")

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
        }
        .invlogCard()
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(items: [shareText])
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
}
