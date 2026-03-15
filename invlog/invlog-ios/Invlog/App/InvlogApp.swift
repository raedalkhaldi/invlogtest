import SwiftUI

@main
struct InvlogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer()
    @StateObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ImagePipelineConfig.setup()
        Self.configureAppearance()
        ErrorLogger.shared.logEvent("App launched — \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))")
    }

    private static func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.brandText)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.brandText)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.brandPrimary)
    }

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
            .environmentObject(appearanceManager)
            .preferredColorScheme(appearanceManager.preferredColorScheme)
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
