import SwiftUI
@preconcurrency import NukeUI

struct MessageThreadView: View {
    @StateObject private var viewModel: MessageThreadViewModel
    @EnvironmentObject private var appState: AppState
    @State private var messageText = ""
    let otherUser: ConversationUser?

    init(conversationId: String, otherUser: ConversationUser?) {
        _viewModel = StateObject(wrappedValue: MessageThreadViewModel(conversationId: conversationId))
        self.otherUser = otherUser
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromMe: message.senderId == appState.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .font(InvlogTheme.body(15))
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brandBorder.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.brandTextTertiary : Color.brandPrimary)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.brandCard)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.brandBorder).frame(height: 0.5)
            }
        }
        .invlogScreenBackground()
        .navigationTitle(otherUser?.displayName ?? otherUser?.username ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
            viewModel.markAsRead()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(InvlogTheme.body(15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromMe ? Color.brandText : Color.brandCard)
                    .foregroundColor(isFromMe ? .white : Color.brandText)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        isFromMe ? nil : RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandBorder, lineWidth: 0.5)
                    )

                Text(message.createdAt, style: .time)
                    .font(InvlogTheme.caption(10))
                    .foregroundColor(Color.brandTextTertiary)
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
    }
}
