import SwiftUI

@main
struct InvlogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .environmentObject(container)
            .onChange(of: scenePhase) { _ in
                if scenePhase == .active {
                    appState.refreshUnreadCount()
                }
            }
            .onChange(of: appState.isAuthenticated) { _ in
                if appState.isAuthenticated {
                    PushNotificationManager.shared.requestPermission()
                    appState.refreshUnreadCount()
                }
            }
        }
    }
}
