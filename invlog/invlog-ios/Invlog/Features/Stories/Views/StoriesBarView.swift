import SwiftUI
import NukeUI

struct StoriesBarView: View {
    let storyGroups: [StoryGroup]
    @State private var selectedGroup: StoryGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(storyGroups) { group in
                    Button {
                        selectedGroup = group
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                // Ring
                                Circle()
                                    .strokeBorder(
                                        group.hasUnviewed
                                            ? LinearGradient(
                                                colors: [.orange, .pink, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            : LinearGradient(
                                                colors: [Color(.systemGray4)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 64, height: 64)

                                // Avatar
                                LazyImage(url: group.user.avatarUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                            }

                            Text(group.user.displayName ?? group.user.username ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(width: 68)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.user.displayName ?? group.user.username ?? "")'s story\(group.hasUnviewed ? ", new" : "")")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .fullScreenCover(item: $selectedGroup) { group in
            StoryViewerView(
                storyGroups: storyGroups,
                initialGroup: group
            )
        }
    }
}
