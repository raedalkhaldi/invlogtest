import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .feed
    @State private var previousTab: Tab = .feed
    @State private var showCreatePost = false

    enum Tab: Int, CaseIterable {
        case feed
        case search
        case create
        case notifications
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Feed
            NavigationStack {
                FeedView()
            }
            .tag(Tab.feed)
            .tabItem {
                Label("Feed", systemImage: "fork.knife")
            }

            // Tab 2: Search / Discover
            NavigationStack {
                SearchView()
            }
            .tag(Tab.search)
            .tabItem {
                Label("Discover", systemImage: "magnifyingglass")
            }

            // Tab 3: Create Post (placeholder, triggers sheet)
            Color.clear
                .tag(Tab.create)
                .tabItem {
                    Label("Check In", systemImage: "mappin.circle.fill")
                }

            // Tab 4: Notifications
            NavigationStack {
                NotificationsListView()
            }
            .tag(Tab.notifications)
            .tabItem {
                Label("Activity", systemImage: "bell")
            }
            .badge(appState.unreadNotificationCount)

            // Tab 5: Profile
            NavigationStack {
                ProfileView(userId: nil)
            }
            .tag(Tab.profile)
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .create {
                showCreatePost = true
                selectedTab = previousTab
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showCreatePost) {
            NavigationStack {
                CreatePostView()
            }
        }
    }
}
