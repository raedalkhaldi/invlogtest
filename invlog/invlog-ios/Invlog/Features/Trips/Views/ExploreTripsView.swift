import SwiftUI
import NukeUI

struct ExploreTripsView: View {
    @StateObject private var viewModel = TripsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.trips.isEmpty {
                ProgressView("Loading trips...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.trips.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Try Again",
                    buttonAction: {
                        Task { await viewModel.loadExploreTrips() }
                    }
                )
            } else if viewModel.trips.isEmpty {
                EmptyStateView(
                    systemImage: "map",
                    title: "No trips yet",
                    description: "Be the first to share a food trip itinerary with the community!",
                    buttonTitle: nil,
                    buttonAction: nil
                )
            } else {
                tripsList
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Food Trips")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadExploreTrips()
        }
    }

    // MARK: - Trips List

    private var tripsList: some View {
        List {
            ForEach(viewModel.trips) { trip in
                NavigationLink(value: trip) {
                    TripCardView(trip: trip)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .onAppear {
                    if trip.id == viewModel.trips.last?.id && viewModel.hasMore {
                        Task { await viewModel.loadMoreExploreTrips() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            viewModel.trips = []
            await viewModel.loadExploreTrips()
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(tripId: trip.id)
        }
    }
}
