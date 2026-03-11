import Foundation
import Combine

final class TripDetailViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var isLoading = false
    @Published var error: String?
    @Published var actionError: String?

    private let tripId: String
    private let apiClient: APIClient

    init(tripId: String, apiClient: APIClient = .shared) {
        self.tripId = tripId
        self.apiClient = apiClient
    }

    // MARK: - Load Trip

    func loadTrip() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let (trip, _) = try await apiClient.requestWrapped(
                .tripDetail(id: tripId),
                responseType: Trip.self
            )
            self.trip = trip
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Update Trip

    func updateTrip(
        title: String? = nil,
        description: String? = nil,
        visibility: String? = nil,
        status: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> Bool {
        actionError = nil
        do {
            let (updated, _) = try await apiClient.requestWrapped(
                .updateTrip(id: tripId, title: title, description: description, visibility: visibility, status: status, startDate: startDate, endDate: endDate),
                responseType: Trip.self
            )
            self.trip = updated
            NotificationCenter.default.post(name: .didUpdateTrip, object: nil)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Add Stop

    func addStop(
        name: String,
        restaurantId: String?,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        dayNumber: Int,
        sortOrder: Int,
        notes: String?,
        category: String,
        estimatedDuration: Int?,
        startTime: String?,
        endTime: String?
    ) async -> Bool {
        actionError = nil
        do {
            let (updated, _) = try await apiClient.requestWrapped(
                .addTripStop(
                    tripId: tripId,
                    name: name,
                    restaurantId: restaurantId,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    dayNumber: dayNumber,
                    sortOrder: sortOrder,
                    notes: notes,
                    category: category,
                    estimatedDuration: estimatedDuration,
                    startTime: startTime,
                    endTime: endTime
                ),
                responseType: Trip.self
            )
            self.trip = updated
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Remove Stop

    func removeStop(_ stopId: String) async -> Bool {
        actionError = nil
        do {
            try await apiClient.requestVoid(.removeTripStop(stopId: stopId))
            // Reload trip to get updated stops
            await loadTrip()
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Invite Collaborator

    func inviteCollaborator(userId: String, role: String) async -> Bool {
        actionError = nil
        do {
            let (updated, _) = try await apiClient.requestWrapped(
                .inviteCollaborator(tripId: tripId, userId: userId, role: role),
                responseType: Trip.self
            )
            self.trip = updated
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Remove Collaborator

    func removeCollaborator(userId: String) async -> Bool {
        actionError = nil
        do {
            try await apiClient.requestVoid(.removeCollaborator(tripId: tripId, userId: userId))
            await loadTrip()
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    // MARK: - Clone Trip

    func cloneTrip() async -> Trip? {
        actionError = nil
        do {
            let (cloned, _) = try await apiClient.requestWrapped(
                .cloneTrip(id: tripId),
                responseType: Trip.self
            )
            NotificationCenter.default.post(name: .didCreateTrip, object: nil)
            return cloned
        } catch {
            actionError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Helpers

    /// Stops organized by day number
    var stopsByDay: [(day: Int, stops: [TripStop])] {
        guard let stops = trip?.stops else { return [] }
        let grouped = Dictionary(grouping: stops) { $0.dayNumber }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, stops: $0.value.sorted { $0.sortOrder < $1.sortOrder }) }
    }

    /// The maximum day number currently used
    var maxDayNumber: Int {
        trip?.stops?.map(\.dayNumber).max() ?? 0
    }

    /// Current stop count for computing the next sortOrder
    func nextSortOrder(forDay day: Int) -> Int {
        let stopsInDay = trip?.stops?.filter { $0.dayNumber == day } ?? []
        return (stopsInDay.map(\.sortOrder).max() ?? -1) + 1
    }

    /// Whether the current user is the owner
    func isOwner(currentUserId: String?) -> Bool {
        guard let currentUserId, let trip else { return false }
        return trip.ownerId == currentUserId
    }

    /// Whether the current user can edit (owner or editor collaborator)
    func canEdit(currentUserId: String?) -> Bool {
        guard let currentUserId, let trip else { return false }
        if trip.ownerId == currentUserId { return true }
        return trip.collaborators?.contains { $0.userId == currentUserId && $0.role == "editor" } ?? false
    }
}
