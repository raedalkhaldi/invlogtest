import Foundation

@MainActor
final class StoriesViewModel: ObservableObject {
    @Published var storyGroups: [StoryGroup] = []
    @Published var isLoading = false

    func loadStories() async {
        isLoading = true
        do {
            let (groups, _) = try await APIClient.shared.requestWrapped(.storyFeed, responseType: [StoryGroup].self)
            storyGroups = groups
        } catch {
            print("Failed to load stories: \(error)")
        }
        isLoading = false
    }

    func markViewed(_ storyId: String) {
        Task {
            try? await APIClient.shared.requestVoid(.viewStory(id: storyId))
        }
    }
}
