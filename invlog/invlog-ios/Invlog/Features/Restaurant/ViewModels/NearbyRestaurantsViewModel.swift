import Foundation
import CoreLocation
import Combine

final class NearbyRestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    @MainActor
    func loadNearby(lat: Double, lng: Double, radiusKm: Double = 10, limit: Int = 50) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let (data, _) = try await apiClient.requestWrapped(
                .nearbyRestaurants(lat: lat, lng: lng, radiusKm: radiusKm, limit: limit),
                responseType: [Restaurant].self
            )
            restaurants = data.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func refresh(lat: Double, lng: Double) async {
        await loadNearby(lat: lat, lng: lng)
    }
}
