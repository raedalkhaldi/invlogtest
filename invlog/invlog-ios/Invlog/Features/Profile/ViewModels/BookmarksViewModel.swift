import Foundation

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    private var nextCursor: String?

    func loadBookmarks() async {
        isLoading = true
        error = nil

        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .bookmarks(cursor: nil, limit: 20),
                responseType: FeedResponse.self
            )
            posts = response.data
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
                .bookmarks(cursor: cursor, limit: 20),
                responseType: FeedResponse.self
            )
            posts.append(contentsOf: response.data)
            nextCursor = response.nextCursor
        } catch {
            // Silently fail on load more
        }
    }
}
