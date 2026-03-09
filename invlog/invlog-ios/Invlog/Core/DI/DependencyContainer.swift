import Foundation
import Combine

final class DependencyContainer: ObservableObject {
    let apiClient: APIClient
    let keychainManager: KeychainManager

    init() {
        self.apiClient = APIClient.shared
        self.keychainManager = KeychainManager()
    }
}
