import SwiftUI
@preconcurrency import NukeUI

@MainActor
struct StoriesBarView: View {
    let storyGroups: [StoryGroup]
    let currentUser: User?
    @ObservedObject var storiesViewModel: StoriesViewModel
    @State private var selectedGroup: StoryGroup?
    @State private var showCreateStory = false
    @State private var navigateToUsername: String?
    @State private var viewerSessionId: UUID = UUID()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                addStoryButton

                ForEach(storyGroups) { group in
                    Button {
                        viewerSessionId = UUID() // Force fresh viewer on every tap
                        selectedGroup = group
                    } label: {
                        storyAvatarView(for: group)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.user.displayName ?? group.user.username ?? "")'s vlog\(group.hasUnviewed ? ", new" : "")")
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.vertical, InvlogTheme.Spacing.xs)
        }
        .fullScreenCover(item: $selectedGroup) { group in
            StoryViewerView(
                storyGroups: storyGroups,
                initialGroup: group,
                selectedUsername: $navigateToUsername,
                storiesViewModel: storiesViewModel
            )
            .id(viewerSessionId) // Force fresh view on every open
        }
        .sheet(isPresented: $showCreateStory) {
            CreateStoryView()
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let username = navigateToUsername {
                        ProfileView(userId: username)
                    }
                },
                isActive: Binding(
                    get: { navigateToUsername != nil },
                    set: { if !$0 { navigateToUsername = nil } }
                )
            ) { EmptyView() }
            .hidden()
        )
    }

    // MARK: - Add Vlog Button

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
                                    AngularGradient(
                                        colors: [Color.brandPrimary, Color.brandSecondary, Color.brandPrimary],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                                )
                                .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                        )
                    } else {
                        placeholderAvatar
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        AngularGradient(
                                            colors: [Color.brandPrimary, Color.brandSecondary, Color.brandPrimary],
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                                    )
                                    .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                            )
                    }

                    // Plus badge - more prominent with branded gradient background
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(Circle().fill(Color.brandCard).frame(width: 22, height: 22))
                }
                .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)

                Text("Add Vlog")
                    .font(InvlogTheme.caption(10, weight: .semibold))
                    .foregroundColor(Color.brandPrimary)
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to your vlog")
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
                if group.hasUnviewed {
                    // Vibrant angular gradient ring for unwatched stories
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary, Color.brandPrimary],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                } else {
                    // Dimmed gray ring for already-watched stories
                    Circle()
                        .strokeBorder(
                            Color.brandBorder.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: InvlogTheme.Avatar.storyRing, height: InvlogTheme.Avatar.storyRing)
                }

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
