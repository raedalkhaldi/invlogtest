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
    @State private var isDismissing = false

    // Pinch-to-zoom
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    // Double-tap to like
    @State private var showHeartBurst = false

    // Reply text field
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool

    // Sound indicator
    @State private var showSoundIndicator = true
    @State private var soundIndicatorOpacity: Double = 1.0
    @ObservedObject private var muteManager = VideoMuteManager.shared

    // Cube transition / crossfade
    @State private var dragOffset: CGFloat = 0
    @State private var crossfadeOpacity: Double = 1.0
    // Track whether last navigation was within same group (crossfade) or between groups (cube)
    @State private var previousGroupIndex: Int = 0

    init(storyGroups: [StoryGroup], initialGroup: StoryGroup, selectedUsername: Binding<String?> = .constant(nil), storiesViewModel: StoriesViewModel) {
        self.storyGroups = storyGroups
        self.initialGroup = initialGroup
        self._selectedUsername = selectedUsername
        self.storiesViewModel = storiesViewModel
        let idx = storyGroups.firstIndex(where: { $0.id == initialGroup.id }) ?? 0
        _currentGroupIndex = State(initialValue: idx)
        _previousGroupIndex = State(initialValue: idx)
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
                // Story content with pinch-to-zoom and cube transition
                storyContent(story: story, group: group)
                    .scaleEffect(zoomScale)
                    .gesture(pinchGesture)
                    .opacity(crossfadeOpacity)
                    // Cube rotation 3D effect based on drag offset
                    .rotation3DEffect(
                        .degrees(Double(dragOffset / UIScreen.main.bounds.width) * 90),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: dragOffset > 0 ? .leading : .trailing,
                        perspective: 0.5
                    )

                // Tap zones (only when not zoomed)
                if zoomScale <= 1.0 {
                    tapZones
                }

                // Overlay UI
                VStack(spacing: 0) {
                    // Progress bars
                    progressBars(group: group)

                    // User info + actions
                    userInfoBar(story: story, group: group)

                    Spacer()

                    // Heart burst animation
                    if showHeartBurst {
                        heartBurstView
                    }

                    Spacer()

                    // Sound indicator (fades out after 2 seconds)
                    if story.mediaType == "video" {
                        soundIndicator
                    }

                    // Reply text field (not shown for own stories)
                    if !isOwnStory {
                        replyField
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onChanged { value in
                    // Horizontal drag for cube transition between groups
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 && abs(value.translation.width) < abs(value.translation.height) {
                        isDismissing = true
                        dismiss()
                    } else if value.translation.width < -80 {
                        // Swipe left -> next group
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragOffset = -UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            nextGroup()
                            dragOffset = 0
                        }
                    } else if value.translation.width > 80 {
                        // Swipe right -> previous group
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragOffset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            previousGroup()
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onTapGesture(count: 2) {
            triggerHeartBurst()
        }
        .onAppear {
            startTimer()
            markCurrentAsViewed()
            startSoundIndicatorFadeOut()
        }
        .onDisappear {
            isDismissing = true
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
                                isDismissing = true
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

    // MARK: - Story Content

    @ViewBuilder
    private func storyContent(story: Story, group: StoryGroup) -> some View {
        GeometryReader { geometry in
            if story.mediaType == "video", let videoUrl = URL(string: story.url), !isDismissing {
                AutoPlayVideoView(
                    url: videoUrl,
                    thumbnailUrl: story.thumbnailUrl.flatMap { URL(string: $0) },
                    blurhash: story.blurhash,
                    durationSecs: story.durationSecs
                )
                .id(story.id) // Force player recreation when story changes
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
    }

    // MARK: - Tap Zones

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { previousStory() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { nextStory() }
        }
    }

    // MARK: - Progress Bars

    private func progressBars(group: StoryGroup) -> some View {
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
    }

    // MARK: - User Info Bar

    private func userInfoBar(story: Story, group: StoryGroup) -> some View {
        HStack(spacing: 10) {
            Button {
                selectedUsername = group.user.username
                isDismissing = true
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
                isDismissing = true
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
    }

    // MARK: - Heart Burst Animation

    private var heartBurstView: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundColor(.red)
            .scaleEffect(showHeartBurst ? 1.2 : 0.5)
            .opacity(showHeartBurst ? 0 : 1)
            .animation(
                .easeOut(duration: 0.8),
                value: showHeartBurst
            )
    }

    private func triggerHeartBurst() {
        showHeartBurst = false
        withAnimation {
            showHeartBurst = true
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showHeartBurst = false
        }
    }

    // MARK: - Sound Indicator

    private var soundIndicator: some View {
        HStack {
            Image(systemName: muteManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.title3)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .onTapGesture {
                    muteManager.toggle()
                    // Reset the indicator visibility briefly on tap
                    soundIndicatorOpacity = 1.0
                    startSoundIndicatorFadeOut()
                }
        }
        .opacity(soundIndicatorOpacity)
        .padding(.bottom, 8)
    }

    private func startSoundIndicatorFadeOut() {
        soundIndicatorOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                soundIndicatorOpacity = 0
            }
        }
    }

    // MARK: - Reply Text Field

    private var replyField: some View {
        HStack(spacing: 10) {
            TextField("Send message...", text: $replyText)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
                .focused($isReplyFocused)
                .onTapGesture {
                    timer?.invalidate()
                }

            if !replyText.isEmpty {
                Button {
                    sendReply()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                        .foregroundColor(Color.brandPrimary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: replyText.isEmpty)
    }

    private func sendReply() {
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // TODO: Implement story reply API
        replyText = ""
        isReplyFocused = false
        startTimer()
    }

    // MARK: - Pinch Gesture

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastZoomScale
                lastZoomScale = value
                zoomScale = min(max(zoomScale * delta, 1.0), 4.0)
            }
            .onEnded { _ in
                lastZoomScale = 1.0
                withAnimation(.easeOut(duration: 0.2)) {
                    zoomScale = 1.0
                }
            }
    }

    // MARK: - Navigation Helpers

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
            // Within same group: crossfade transition
            previousGroupIndex = currentGroupIndex
            withAnimation(.easeInOut(duration: 0.15)) {
                crossfadeOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                currentStoryIndex += 1
                markCurrentAsViewed()
                startTimer()
                withAnimation(.easeInOut(duration: 0.15)) {
                    crossfadeOpacity = 1
                }
            }
        } else if currentGroupIndex < storyGroups.count - 1 {
            previousGroupIndex = currentGroupIndex
            currentGroupIndex += 1
            currentStoryIndex = 0
            markCurrentAsViewed()
            startTimer()
        } else {
            isDismissing = true
            dismiss()
        }
    }

    private func previousStory() {
        if currentStoryIndex > 0 {
            // Within same group: crossfade transition
            previousGroupIndex = currentGroupIndex
            withAnimation(.easeInOut(duration: 0.15)) {
                crossfadeOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                currentStoryIndex -= 1
                startTimer()
                withAnimation(.easeInOut(duration: 0.15)) {
                    crossfadeOpacity = 1
                }
            }
        } else if currentGroupIndex > 0 {
            previousGroupIndex = currentGroupIndex
            currentGroupIndex -= 1
            currentStoryIndex = (currentGroup?.stories.count ?? 1) - 1
            startTimer()
        } else {
            startTimer() // Restart current
        }
    }

    private func nextGroup() {
        if currentGroupIndex < storyGroups.count - 1 {
            previousGroupIndex = currentGroupIndex
            currentGroupIndex += 1
            currentStoryIndex = 0
            markCurrentAsViewed()
            startTimer()
        } else {
            isDismissing = true
            dismiss()
        }
    }

    private func previousGroup() {
        if currentGroupIndex > 0 {
            previousGroupIndex = currentGroupIndex
            currentGroupIndex -= 1
            currentStoryIndex = 0
            startTimer()
        } else {
            startTimer()
        }
    }

    private func markCurrentAsViewed() {
        guard let story = currentStory else { return }
        Task {
            try? await APIClient.shared.requestVoid(.viewStory(id: story.id))
        }
    }
}
