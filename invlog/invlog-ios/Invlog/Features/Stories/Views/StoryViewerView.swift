import SwiftUI
@preconcurrency import NukeUI

struct StoryViewerView: View {
    let storyGroups: [StoryGroup]
    let initialGroup: StoryGroup
    @Binding var selectedUsername: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var storiesViewModel: StoriesViewModel

    @State private var currentGroupIndex: Int = 0
    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var showDeleteConfirm = false

    init(storyGroups: [StoryGroup], initialGroup: StoryGroup, selectedUsername: Binding<String?> = .constant(nil), storiesViewModel: StoriesViewModel) {
        self.storyGroups = storyGroups
        self.initialGroup = initialGroup
        self._selectedUsername = selectedUsername
        self.storiesViewModel = storiesViewModel
        let idx = storyGroups.firstIndex(where: { $0.id == initialGroup.id }) ?? 0
        _currentGroupIndex = State(initialValue: idx)
    }

    private var currentGroup: StoryGroup? {
        guard currentGroupIndex < storyGroups.count else { return nil }
        return storyGroups[currentGroupIndex]
    }

    private var currentStory: Story? {
        guard let group = currentGroup,
              currentStoryIndex < group.stories.count else { return nil }
        return group.stories[currentStoryIndex]
    }

    /// Whether the current story belongs to the logged-in user
    private var isOwnStory: Bool {
        guard let story = currentStory else { return false }
        return story.authorId == appState.currentUser?.id
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let story = currentStory, let group = currentGroup {
                // Story content
                GeometryReader { geometry in
                    if story.mediaType == "video", let videoUrl = URL(string: story.url) {
                        AutoPlayVideoView(
                            url: videoUrl,
                            thumbnailUrl: story.thumbnailUrl.flatMap { URL(string: $0) },
                            blurhash: story.blurhash
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        LazyImage(url: URL(string: story.url)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            } else if state.isLoading {
                                ZStack {
                                    if let blurhash = story.blurhash {
                                        BlurhashView(blurhash: blurhash)
                                    }
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .ignoresSafeArea()

                // Tap zones
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { previousStory() }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { nextStory() }
                }

                // Overlay UI
                VStack {
                    // Progress bars
                    HStack(spacing: 3) {
                        ForEach(0..<group.stories.count, id: \.self) { index in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.3))
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: barWidth(for: index, totalWidth: geo.size.width))
                                }
                            }
                            .frame(height: 2.5)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    // User info + actions
                    HStack(spacing: 10) {
                        Button {
                            selectedUsername = group.user.username
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                LazyImage(url: group.user.avatarUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                                Text(group.user.displayName ?? group.user.username ?? "")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        Text(story.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        // Delete button (own vlogs only)
                        if isOwnStory {
                            Button {
                                timer?.invalidate()
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Delete vlog")
                        }

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Close vlogs")
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            startTimer()
            markCurrentAsViewed()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .statusBarHidden()
        .alert("Delete Vlog", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let story = currentStory else { return }
                Task {
                    let success = await storiesViewModel.deleteStory(story.id)
                    if success {
                        // Move to next story or dismiss if none left
                        if let group = currentGroup, group.stories.isEmpty {
                            if storyGroups.isEmpty {
                                dismiss()
                            } else {
                                // Group was removed, adjust index
                                if currentGroupIndex >= storyGroups.count {
                                    currentGroupIndex = max(0, storyGroups.count - 1)
                                }
                                currentStoryIndex = 0
                                startTimer()
                            }
                        } else {
                            nextStory()
                        }
                    } else {
                        startTimer()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                startTimer()
            }
        } message: {
            Text("Are you sure you want to delete this vlog?")
        }
    }

    private func barWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentStoryIndex {
            return totalWidth
        } else if index == currentStoryIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        progress = 0
        let defaultDuration: Double = currentStory?.mediaType == "video" ? 30.0 : 5.0
        let duration: Double = currentStory?.durationSecs ?? defaultDuration
        let interval: Double = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                progress += CGFloat(interval / duration)
                if progress >= 1 {
                    nextStory()
                }
            }
        }
    }

    private func nextStory() {
        guard let group = currentGroup else { return }

        if currentStoryIndex < group.stories.count - 1 {
            currentStoryIndex += 1
            markCurrentAsViewed()
            startTimer()
        } else if currentGroupIndex < storyGroups.count - 1 {
            currentGroupIndex += 1
            currentStoryIndex = 0
            markCurrentAsViewed()
            startTimer()
        } else {
            dismiss()
        }
    }

    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            startTimer()
        } else if currentGroupIndex > 0 {
            currentGroupIndex -= 1
            currentStoryIndex = (currentGroup?.stories.count ?? 1) - 1
            startTimer()
        } else {
            startTimer() // Restart current
        }
    }

    private func markCurrentAsViewed() {
        guard let story = currentStory else { return }
        Task {
            try? await APIClient.shared.requestVoid(.viewStory(id: story.id))
        }
    }
}
