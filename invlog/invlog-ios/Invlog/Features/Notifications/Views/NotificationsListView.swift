import SwiftUI
@preconcurrency import NukeUI

struct NotificationsListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                EmptyStateView(
                    systemImage: "bell",
                    title: "No Activity",
                    description: "When people interact with your posts, you'll see it here"
                )
            } else {
                List {
                    ForEach(notifications) { notification in
                        NotificationRowView(notification: notification)
                            .listRowBackground(notification.isRead ? Color.clear : Color.brandOrangeLight.opacity(0.5))
                            .frame(minHeight: 44)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadNotifications()
                }
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Activity")
        .toolbar {
            if !notifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await markAllRead() }
                    } label: {
                        Text("Read All")
                            .font(InvlogTheme.caption(13, weight: .semibold))
                            .foregroundColor(Color.brandPrimary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Mark all notifications as read")
                }
            }
        }
        .task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .notifications(cursor: nil, limit: 50),
                responseType: [AppNotification].self
            )
            notifications = data
            appState.unreadNotificationCount = data.filter { !$0.isRead }.count
        } catch {
            print("❌ Notifications load error: \(error)")
        }
        isLoading = false
    }

    private func markAllRead() async {
        do {
            try await APIClient.shared.requestVoid(.markAllNotificationsRead)
            for i in notifications.indices {
                notifications[i] = AppNotification(
                    id: notifications[i].id,
                    recipientId: notifications[i].recipientId,
                    actorId: notifications[i].actorId,
                    actor: notifications[i].actor,
                    type: notifications[i].type,
                    targetType: notifications[i].targetType,
                    targetId: notifications[i].targetId,
                    message: notifications[i].message,
                    isRead: true,
                    createdAt: notifications[i].createdAt
                )
            }
            appState.unreadNotificationCount = 0
        } catch {
            // Handle error
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ProfileView(userId: notification.actor?.username ?? "")) {
                LazyImage(url: notification.actor?.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: iconForType)
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(notificationText)
                    .font(InvlogTheme.body(14))
                    .lineLimit(2)

                Text(notification.createdAt, style: .relative)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextTertiary)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Unread")
            }
        }
    }

    private var iconForType: String {
        switch notification.type {
        case "like_post", "like_comment": return "heart.fill"
        case "comment": return "bubble.right.fill"
        case "follow": return "person.badge.plus"
        case "checkin": return "mappin.circle.fill"
        default: return "bell.fill"
        }
    }

    private var notificationText: AttributedString {
        let actorName = notification.actor?.displayName ?? notification.actor?.username ?? "Someone"
        var text = AttributedString(actorName)
        text.font = InvlogTheme.body(14, weight: .bold)

        switch notification.type {
        case "like_post":
            text.append(AttributedString(" liked your post"))
        case "like_comment":
            text.append(AttributedString(" liked your comment"))
        case "comment":
            text.append(AttributedString(" commented on your post"))
        case "follow":
            text.append(AttributedString(" started following you"))
        case "checkin":
            text.append(AttributedString(" checked in at your place"))
        default:
            if let message = notification.message {
                text.append(AttributedString(" \(message)"))
            }
        }

        return text
    }
}
