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

            // Assign any pending caption from a recent upload to the latest own story
            if let myGroup = groups.first(where: { $0.stories.contains(where: { _ in true }) }),
               let latestStory = myGroup.stories.first {
                StoryCaptionCache.shared.assignPendingCaption(to: latestStory.id)
            }
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

    func deleteStory(_ storyId: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteStory(id: storyId))
            // Remove from local state
            for i in storyGroups.indices {
                storyGroups[i].stories.removeAll { $0.id == storyId }
            }
            // Remove empty groups
            storyGroups.removeAll { $0.stories.isEmpty }
            return true
        } catch {
            print("Failed to delete story: \(error)")
            return false
        }
    }
}
