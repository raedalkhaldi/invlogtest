import Foundation
import Combine

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var hasMore = true
    private var cursor: String?
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - My Trips

    func loadMyTrips() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let (response, _) = try await apiClient.requestWrapped(
                .myTrips(cursor: nil, limit: 20),
                responseType: TripsResponse.self
            )
            trips = response.data
            cursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreMyTrips() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true

        do {
            let (response, _) = try await apiClient.requestWrapped(
                .myTrips(cursor: cursor, limit: 20),
                responseType: TripsResponse.self
            )
            trips.append(contentsOf: response.data)
            self.cursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Explore Trips

    func loadExploreTrips() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let (response, _) = try await apiClient.requestWrapped(
                .exploreTrips(cursor: nil, limit: 20),
                responseType: TripsResponse.self
            )
            trips = response.data
            cursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreExploreTrips() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true

        do {
            let (response, _) = try await apiClient.requestWrapped(
                .exploreTrips(cursor: cursor, limit: 20),
                responseType: TripsResponse.self
            )
            trips.append(contentsOf: response.data)
            self.cursor = response.nextCursor
            hasMore = response.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Delete Trip

    func deleteTrip(_ trip: Trip) async -> Bool {
        do {
            try await apiClient.requestVoid(.deleteTrip(id: trip.id))
            trips.removeAll { $0.id == trip.id }
            NotificationCenter.default.post(name: .didDeleteTrip, object: nil)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Refresh

    func refresh() async {
        cursor = nil
        hasMore = true
        await loadMyTrips()
    }
}
