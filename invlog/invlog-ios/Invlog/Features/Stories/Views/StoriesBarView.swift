import SwiftUI
import NukeUI

struct StoriesBarView: View {
    let storyGroups: [StoryGroup]
    let currentUser: User?
    @State private var selectedGroup: StoryGroup?
    @State private var showCreateStory = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // "Your Story" / Add button — always visible
                addStoryButton

                ForEach(storyGroups) { group in
                    Button {
                        selectedGroup = group
                    } label: {
                        storyAvatarView(for: group)
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
        .sheet(isPresented: $showCreateStory) {
            CreateStoryView()
        }
    }

    // MARK: - Add Story Button

    private var addStoryButton: some View {
        Button {
            showCreateStory = true
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarUrl = currentUser?.avatarUrl {
                        LazyImage(url: avatarUrl) { state in
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
                        .overlay(
                            Circle()
                                .strokeBorder(Color(.systemGray4), lineWidth: 2)
                                .frame(width: 64, height: 64)
                        )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(.systemGray4), lineWidth: 2)
                                    .frame(width: 64, height: 64)
                            )
                    }

                    // Plus badge
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color(.systemBackground)).frame(width: 18, height: 18))
                }
                .frame(width: 64, height: 64)

                Text("Your Story")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to your story")
    }

    // MARK: - Story Avatar

    private func storyAvatarView(for group: StoryGroup) -> some View {
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
}
