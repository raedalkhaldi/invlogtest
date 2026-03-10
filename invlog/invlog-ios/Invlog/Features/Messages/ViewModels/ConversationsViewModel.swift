import Foundation

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: String?
    private var nextCursor: String?

    func loadConversations() async {
        isLoading = true
        error = nil

        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .conversations(cursor: nil, limit: 20),
                responseType: ConversationsResponse.self
            )
            conversations = response.data
            nextCursor = response.nextCursor
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard let cursor = nextCursor else { return }

        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .conversations(cursor: cursor, limit: 20),
                responseType: ConversationsResponse.self
            )
            conversations.append(contentsOf: response.data)
            nextCursor = response.nextCursor
        } catch {
            // Silently fail
        }
    }
}
