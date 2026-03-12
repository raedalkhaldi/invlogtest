import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var unreadNotificationCount = 0

    private let keychainManager = KeychainManager()

    init() {
        checkAuthState()
    }

    func checkAuthState() {
        isAuthenticated = keychainManager.getAccessToken() != nil
        if isAuthenticated {
            loadCurrentUser()
        }
    }

    func loadCurrentUser() {
        Task {
            do {
                let (user, _) = try await APIClient.shared.requestWrapped(
                    .currentUser,
                    responseType: User.self
                )
                await MainActor.run {
                    self.currentUser = user
                }
            } catch {
                // Non-critical — user data will load on next sign-in
            }
        }
    }

    func signIn(accessToken: String, refreshToken: String, user: User) {
        keychainManager.saveAccessToken(accessToken)
        keychainManager.saveRefreshToken(refreshToken)
        currentUser = user
        isAuthenticated = true
    }

    func signOut() {
        keychainManager.clearTokens()
        currentUser = nil
        isAuthenticated = false
        unreadNotificationCount = 0
    }

    func refreshUnreadCount() {
        guard isAuthenticated else { return }
        Task {
            do {
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .unreadNotificationCount,
                    responseType: UnreadCountResponse.self
                )
                await MainActor.run {
                    self.unreadNotificationCount = data.count
                }
            } catch {
                // Silently fail — badge count is non-critical
            }
        }
    }
}

private struct UnreadCountResponse: Decodable {
    let count: Int
}
