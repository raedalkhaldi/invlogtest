import SwiftUI

/// Custom branded share sheet replacing the native UIActivityViewController.
struct CustomShareSheet: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var showNativeShare = false
    @State private var copied = false

    private var shareText: String {
        let author = post.author?.displayName ?? post.author?.username ?? ""
        let place = post.restaurant?.name ?? ""
        let content = post.content ?? ""
        var text = "\(author)"
        if !place.isEmpty { text += " at \(place)" }
        if !content.isEmpty { text += ": \(content)" }
        return text
    }

    private var shareURL: String {
        "https://invlog.app/post/\(post.id)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Title
            Text("Share Post")
                .font(InvlogTheme.body(16, weight: .bold))
                .foregroundColor(Color.brandText)
                .padding(.bottom, 16)

            // Action grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                shareActionButton(icon: copied ? "checkmark.circle.fill" : "doc.on.doc", label: copied ? "Copied!" : "Copy Link", color: copied ? .green : Color.brandText) {
                    UIPasteboard.general.string = shareURL
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                }

                shareActionButton(icon: "message.fill", label: "Message", color: .green) {
                    if let url = URL(string: "sms:&body=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                }

                shareActionButton(icon: "camera.fill", label: "Instagram", color: .purple) {
                    if let url = URL(string: "instagram://app") {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                }

                shareActionButton(icon: "square.and.arrow.up", label: "More", color: Color.brandTextSecondary) {
                    showNativeShare = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.brandCard)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showNativeShare) {
            ShareSheetView(items: [shareText, shareURL])
        }
    }

    private func shareActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .clipShape(Circle())

                Text(label)
                    .font(InvlogTheme.caption(11, weight: .medium))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
