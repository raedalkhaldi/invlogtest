import Foundation

protocol AuthServiceProtocol {
    func register(email: String, password: String, username: String, displayName: String?) async throws -> AuthResponse
    func login(email: String, password: String) async throws -> AuthResponse
    func logout(refreshToken: String) async throws
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

final class AuthService: AuthServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func register(email: String, password: String, username: String, displayName: String?) async throws -> AuthResponse {
        let response: APIResponse<AuthResponse> = try await apiClient.request(
            .register(email: email, password: password, username: username, displayName: displayName),
            responseType: APIResponse<AuthResponse>.self
        )
        return response.data
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let response: APIResponse<AuthResponse> = try await apiClient.request(
            .login(email: email, password: password),
            responseType: APIResponse<AuthResponse>.self
        )
        return response.data
    }

    func logout(refreshToken: String) async throws {
        try await apiClient.requestVoid(.logout(refreshToken: refreshToken))
    }
}
