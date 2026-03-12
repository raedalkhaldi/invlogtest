import SwiftUI
@preconcurrency import NukeUI

@MainActor
struct StoriesBarView: View {
    let storyGroups: [StoryGroup]
    let currentUser: User?
    @State private var selectedGroup: StoryGroup?
    @State private var showCreateStory = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
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
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.vertical, InvlogTheme.Spacing.xs)
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
                                placeholderAvatar
                            }
                        }
                        .frame(width: InvlogTheme.Avatar.storyInner, height: InvlogTheme.Avatar.storyInner)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                )
                                .foregroundColor(Color.brandBorder)
                                .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                        )
                    } else {
                        placeholderAvatar
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                    )
                                    .foregroundColor(Color.brandBorder)
                                    .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                            )
                    }

                    // Plus badge
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.brandPrimary)
                        .background(Circle().fill(Color.brandCard).frame(width: 18, height: 18))
                }
                .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)

                Text("Add Story")
                    .font(InvlogTheme.caption(10, weight: .medium))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to your story")
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 30))
            .foregroundColor(Color.brandTextTertiary)
            .frame(width: InvlogTheme.Avatar.storyInner, height: InvlogTheme.Avatar.storyInner)
    }

    // MARK: - Story Avatar

    private func storyAvatarView(for group: StoryGroup) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .strokeBorder(
                        group.hasUnviewed
                            ? LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.brandBorder],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: 2.5
                    )
                    .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)

                LazyImage(url: group.user.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: InvlogTheme.Avatar.storyInner, height: InvlogTheme.Avatar.storyInner)
                .clipShape(Circle())
            }

            Text(group.user.displayName ?? group.user.username ?? "")
                .font(InvlogTheme.caption(10, weight: .medium))
                .foregroundColor(Color.brandTextSecondary)
                .lineLimit(1)
                .frame(width: 68)
        }
    }
}
