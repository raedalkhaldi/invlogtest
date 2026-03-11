import SwiftUI
import NukeUI

struct StoryViewerView: View {
    let storyGroups: [StoryGroup]
    let initialGroup: StoryGroup
    @Environment(\.dismiss) private var dismiss

    @State private var currentGroupIndex: Int = 0
    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?

    init(storyGroups: [StoryGroup], initialGroup: StoryGroup) {
        self.storyGroups = storyGroups
        self.initialGroup = initialGroup
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

                    // User info + close
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

                        Text(story.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Close stories")
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
        let defaultDuration: Double = currentStory?.mediaType == "video" ? 10.0 : 5.0
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
