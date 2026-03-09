import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoginMode = true

    private let authService: AuthServiceProtocol
    private var appState: AppState?

    init() {
        self.authService = AuthService()
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    func login() async {
        guard !isLoading else { return }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.login(email: email, password: password)
            appState?.signIn(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func register() async {
        guard !isLoading else { return }
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            errorMessage = "Please fill in all required fields"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.register(
                email: email,
                password: password,
                username: username,
                displayName: displayName.isEmpty ? nil : displayName
            )
            appState?.signIn(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleMode() {
        isLoginMode.toggle()
        errorMessage = nil
    }
}
