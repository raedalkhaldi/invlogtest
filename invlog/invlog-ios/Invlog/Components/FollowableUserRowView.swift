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
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                        .lineLimit(1)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text("@\(user.username)")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                toggleFollow()
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(InvlogTheme.caption(13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.brandCard : Color.brandText)
                    .foregroundColor(isFollowing ? Color.brandText : .white)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                            .stroke(isFollowing ? Color.brandBorder : Color.clear, lineWidth: 1)
                    )
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
                isFollowing = wasFollowing
            }
        }
    }
}
