import SwiftUI
import NukeUI

struct FollowableUserRowView: View {
    let user: User
    @State private var isFollowing: Bool

    init(user: User) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowedByMe ?? false)
    }

    var body: some View {
        HStack(spacing: 12) {
            LazyImage(url: user.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                toggleFollow()
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.accentColor)
                    .foregroundColor(isFollowing ? .primary : .white)
                    .clipShape(Capsule())
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(isFollowing ? "Unfollow \(user.displayName ?? user.username)" : "Follow \(user.displayName ?? user.username)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func toggleFollow() {
        let wasFollowing = isFollowing
        isFollowing.toggle()
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.requestVoid(.followUser(id: user.id))
                } else {
                    try await APIClient.shared.requestVoid(.unfollowUser(id: user.id))
                }
            } catch {
                isFollowing = wasFollowing // revert on error
            }
        }
    }
}
