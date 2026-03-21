import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .feed
    @State private var showCreatePost = false
    @State private var showCreateTrip = false
    @State private var showCreateOptions = false

    // Navigation paths for pop-to-root on re-tap
    @State private var feedPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var notificationsPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    // Smooth swipe state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var gestureOffset: CGFloat = 0

    enum Tab: Int, CaseIterable {
        case feed
        case search
        case create
        case notifications
        case profile
    }

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width

            ZStack(alignment: .bottom) {
                // Content — smooth sliding tabs
                ZStack {
                    ForEach(navigableTabs, id: \.rawValue) { tab in
                        tabContent(for: tab)
                            .frame(width: screenWidth)
                            .offset(x: offsetForTab(tab, screenWidth: screenWidth))
                    }
                }
                .gesture(
                    isAtTabRoot ?
                    DragGesture(minimumDistance: 25, coordinateSpace: .local)
                        .updating($gestureOffset) { value, state, _ in
                            // Only allow horizontal swipes
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                            state = value.translation.width
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }

                            let threshold: CGFloat = screenWidth * 0.25
                            let velocity = value.predictedEndTranslation.width - value.translation.width

                            if value.translation.width + velocity < -threshold {
                                switchToAdjacentTab(forward: true)
                            } else if value.translation.width + velocity > threshold {
                                switchToAdjacentTab(forward: false)
                            }
                        }
                    : nil
                )
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: InvlogTheme.TabBar.contentHeight)
                }

                // Custom tab bar overlay
                CustomTabBarView(
                    selectedTab: $selectedTab,
                    onCreateTapped: { showCreateOptions = true },
                    unreadCount: appState.unreadNotificationCount,
                    onTabReselected: { tab in
                        popToRoot(tab)
                    }
                )
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .notifications {
                NotificationCenter.default.post(name: .didSelectNotificationsTab, object: nil)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .confirmationDialog("Create", isPresented: $showCreateOptions, titleVisibility: .hidden) {
            Button {
                showCreatePost = true
            } label: {
                Label("Check In", systemImage: "mappin.and.ellipse")
            }
            Button {
                showCreateTrip = true
            } label: {
                Label("Create Trip", systemImage: "map")
            }
        }
        .sheet(isPresented: $showCreatePost) {
            NavigationStack {
                CreatePostView()
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            NavigationStack {
                CreateTripView()
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .feed:
            NavigationStack(path: $feedPath) { FeedView() }
        case .search:
            NavigationStack(path: $searchPath) { SearchView() }
        case .notifications:
            NavigationStack(path: $notificationsPath) { NotificationsListView() }
        case .profile:
            NavigationStack(path: $profilePath) { ProfileView(userId: nil) }
        case .create:
            EmptyView()
        }
    }

    // MARK: - Smooth Swipe Navigation

    private let navigableTabs: [Tab] = [.feed, .search, .notifications, .profile]

    private var currentTabIndex: Int {
        navigableTabs.firstIndex(of: selectedTab) ?? 0
    }

    private func offsetForTab(_ tab: Tab, screenWidth: CGFloat) -> CGFloat {
        guard let tabIndex = navigableTabs.firstIndex(of: tab) else { return 0 }
        let indexDiff = CGFloat(tabIndex - currentTabIndex)
        let baseOffset = indexDiff * screenWidth

        // Only show adjacent tabs (current ± 1) for performance
        if abs(indexDiff) > 1 && gestureOffset == 0 {
            return baseOffset // Off-screen, won't be visible
        }

        return baseOffset + gestureOffset
    }

    private var isAtTabRoot: Bool {
        switch selectedTab {
        case .feed: return feedPath.isEmpty
        case .search: return searchPath.isEmpty
        case .notifications: return notificationsPath.isEmpty
        case .profile: return profilePath.isEmpty
        case .create: return true
        }
    }

    private func switchToAdjacentTab(forward: Bool) {
        let nextIndex = forward
            ? min(currentTabIndex + 1, navigableTabs.count - 1)
            : max(currentTabIndex - 1, 0)
        guard nextIndex != currentTabIndex else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selectedTab = navigableTabs[nextIndex]
        }
    }

    private func popToRoot(_ tab: Tab) {
        switch tab {
        case .feed: feedPath = NavigationPath()
        case .search: searchPath = NavigationPath()
        case .notifications: notificationsPath = NavigationPath()
        case .profile: profilePath = NavigationPath()
        case .create: break
        }
    }
}
