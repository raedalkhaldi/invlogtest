import SwiftUI
import NukeUI

struct ConversationsListView: View {
    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showNewConversation = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.conversations.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Retry",
                    buttonAction: { Task { await viewModel.loadConversations() } }
                )
            } else if viewModel.conversations.isEmpty {
                EmptyStateView(
                    systemImage: "paperplane",
                    title: "No Messages",
                    description: "Start a conversation to message someone."
                )
            } else {
                List {
                    ForEach(viewModel.conversations) { conversation in
                        NavigationLink(destination: MessageThreadView(
                            conversationId: conversation.id,
                            otherUser: conversation.otherUser
                        )) {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowBackground(Color.clear)
                        .onAppear {
                            if conversation.id == viewModel.conversations.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(Color.brandText)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("New message")
            }
        }
        .sheet(isPresented: $showNewConversation) {
            NewConversationView()
        }
        .task {
            await viewModel.loadConversations()
        }
        .refreshable {
            await viewModel.loadConversations()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            LazyImage(url: conversation.otherUser?.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser?.displayName ?? conversation.otherUser?.username ?? "User")
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                        .lineLimit(1)

                    Spacer()

                    if let lastAt = conversation.lastMessageAt {
                        Text(lastAt, style: .relative)
                            .font(InvlogTheme.caption(11))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }

                HStack {
                    Text(conversation.lastMessageText ?? "No messages yet")
                        .font(InvlogTheme.body(13))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(1)

                    Spacer()

                    if let unread = conversation.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(InvlogTheme.caption(11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.brandPrimary))
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
