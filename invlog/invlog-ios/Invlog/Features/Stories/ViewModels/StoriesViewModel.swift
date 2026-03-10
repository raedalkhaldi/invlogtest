import Foundation

@MainActor
final class StoriesViewModel: ObservableObject {
    @Published var storyGroups: [StoryGroup] = []
    @Published var isLoading = false

    func loadStories() async {
        isLoading = true
        do {
            let groups = try await APIClient.shared.request(.storyFeed, responseType: [StoryGroup].self)
            storyGroups = groups
        } catch {
            // Silently handle — stories bar just stays empty
        }
        isLoading = false
    }

    func markViewed(_ storyId: String) {
        Task {
            try? await APIClient.shared.requestVoid(.viewStory(id: storyId))
        }
    }
}
