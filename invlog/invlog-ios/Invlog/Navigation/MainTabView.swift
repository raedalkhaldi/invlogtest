import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .feed
    @State private var showCreatePost = false
    @State private var showCreateTrip = false
    @State private var showCreateOptions = false

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
                NavigationStack {
                    FeedView()
                }
                .opacity(selectedTab == .feed ? 1 : 0)

                NavigationStack {
                    SearchView()
                }
                .opacity(selectedTab == .search ? 1 : 0)

                NavigationStack {
                    NotificationsListView()
                }
                .opacity(selectedTab == .notifications ? 1 : 0)

                NavigationStack {
                    ProfileView(userId: nil)
                }
                .opacity(selectedTab == .profile ? 1 : 0)
            }

            // Custom tab bar overlay
            CustomTabBarView(
                selectedTab: $selectedTab,
                onCreateTapped: { showCreateOptions = true },
                unreadCount: appState.unreadNotificationCount
            )
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
}
