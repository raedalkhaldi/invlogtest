import SwiftUI

/// Animated emoji reaction picker that appears above the like button.
/// Cosmetic only — backend only supports like/unlike.
struct ReactionPickerView: View {
    let onSelect: (String) -> Void

    private let reactions = ["❤️", "🔥", "😍", "👏", "🤤", "⭐"]
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .scaleEffect(appeared ? 1.0 : 0.3)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.6)
                                .delay(Double(index) * 0.04),
                            value: appeared
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .scaleEffect(appeared ? 1 : 0.5, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
