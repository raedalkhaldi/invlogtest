import Foundation

@MainActor
final class MessageThreadViewModel: ObservableObject {
    let conversationId: String
    @Published var messages: [Message] = []
    @Published var isLoading = false
    private var nextCursor: String?
    private var pollTimer: Timer?

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    func loadMessages() async {
        isLoading = true

        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .messages(conversationId: conversationId, cursor: nil, limit: 30),
                responseType: MessagesResponse.self
            )
            messages = response.data.reversed() // Oldest first for chat display
            nextCursor = response.nextCursor
        } catch {
            // Handle error silently
        }

        isLoading = false
    }

    func loadOlder() async {
        guard let cursor = nextCursor else { return }

        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .messages(conversationId: conversationId, cursor: cursor, limit: 30),
                responseType: MessagesResponse.self
            )
            let older = response.data.reversed()
            messages.insert(contentsOf: older, at: 0)
            nextCursor = response.nextCursor
        } catch {
            // Silently fail
        }
    }

    func sendMessage(_ content: String) async {
        do {
            let message = try await APIClient.shared.request(
                .sendMessage(conversationId: conversationId, content: content),
                responseType: Message.self
            )
            messages.append(message)
        } catch {
            // Handle error
        }
    }

    func markAsRead() {
        Task {
            try? await APIClient.shared.requestVoid(
                .markConversationRead(conversationId: conversationId)
            )
        }
    }

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.pollNewMessages()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollNewMessages() async {
        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .messages(conversationId: conversationId, cursor: nil, limit: 30),
                responseType: MessagesResponse.self
            )
            let newMessages = response.data.reversed()
            if newMessages.count != messages.count {
                messages = Array(newMessages)
            }
        } catch {
            // Silent
        }
    }
}
