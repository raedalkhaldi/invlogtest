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

    enum Tab: Int, CaseIterable {
        case feed
        case search
        case create
        case notifications
        case profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content — all tabs alive via opacity for state preservation
            ZStack {
                NavigationStack(path: $feedPath) {
                    FeedView()
                }
                .opacity(selectedTab == .feed ? 1 : 0)

                NavigationStack(path: $searchPath) {
                    SearchView()
                }
                .opacity(selectedTab == .search ? 1 : 0)

                NavigationStack(path: $notificationsPath) {
                    NotificationsListView()
                }
                .opacity(selectedTab == .notifications ? 1 : 0)

                NavigationStack(path: $profilePath) {
                    ProfileView(userId: nil)
                }
                .opacity(selectedTab == .profile ? 1 : 0)
            }
            .gesture(
                DragGesture(minimumDistance: 60, coordinateSpace: .local)
                    .onEnded { value in
                        guard isAtTabRoot else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        if value.translation.width < -60 {
                            switchToAdjacentTab(forward: true)
                        } else if value.translation.width > 60 {
                            switchToAdjacentTab(forward: false)
                        }
                    }
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

    // MARK: - Swipe Tab Navigation

    private let navigableTabs: [Tab] = [.feed, .search, .notifications, .profile]

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
        guard let currentIndex = navigableTabs.firstIndex(of: selectedTab) else { return }
        let nextIndex = forward
            ? min(currentIndex + 1, navigableTabs.count - 1)
            : max(currentIndex - 1, 0)
        guard nextIndex != currentIndex else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
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
