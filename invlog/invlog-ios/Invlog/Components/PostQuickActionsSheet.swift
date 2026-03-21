import SwiftUI

/// Bottom sheet with quick actions for a post (replaces context menu).
struct PostQuickActionsSheet: View {
    let post: Post
    let isOwnPost: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    let onCopyLink: () -> Void
    let onBookmark: () -> Void
    let onReport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Actions
            VStack(spacing: 0) {
                if isOwnPost {
                    actionRow(icon: "pencil", label: "Edit Post") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onEdit() }
                    }
                    actionRow(icon: "square.and.arrow.up", label: "Share") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShare() }
                    }
                    actionRow(icon: "link", label: "Copy Link") {
                        UIPasteboard.general.string = "https://invlog.app/post/\(post.id)"
                        dismiss()
                    }
                    actionRow(icon: "trash", label: "Delete Post", isDestructive: true) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDelete() }
                    }
                } else {
                    actionRow(icon: "bookmark", label: "Save") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onBookmark() }
                    }
                    actionRow(icon: "square.and.arrow.up", label: "Share") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShare() }
                    }
                    actionRow(icon: "link", label: "Copy Link") {
                        UIPasteboard.general.string = "https://invlog.app/post/\(post.id)"
                        dismiss()
                    }
                    actionRow(icon: "flag", label: "Report", isDestructive: true) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onReport() }
                    }
                }
            }

            Spacer().frame(height: 8)
        }
        .background(Color.brandCard)
        .presentationDetents([.height(isOwnPost ? 280 : 280)])
        .presentationDragIndicator(.hidden)
    }

    private func actionRow(icon: String, label: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                Text(label)
                    .font(InvlogTheme.body(16, weight: .medium))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red : Color.brandText)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
