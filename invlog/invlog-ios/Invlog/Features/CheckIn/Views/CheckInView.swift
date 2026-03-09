import SwiftUI
import CoreLocation

struct CheckInView: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Restaurant Info
                VStack(spacing: 12) {
                    AsyncImage(url: restaurant.avatarUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                    Text(restaurant.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                        Text(cuisines.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Location status
                if let location = locationManager.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Location detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Your location has been detected")
                } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Getting your location...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Success feedback
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Checked in successfully!")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Check In Button
                Button {
                    Task { await performCheckIn() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "mappin.and.ellipse")
                        Text("Check In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(showSuccess ? Color.green : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(minHeight: 44)
                .disabled(isSubmitting || showSuccess)
                .padding(.horizontal)
                .accessibilityLabel("Check in at \(restaurant.name)")
            }
            .padding()
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Cancel check-in")
                }
            }
            .onAppear {
                let status = locationManager.authorizationStatus
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.startUpdating()
                } else if status == .notDetermined {
                    locationManager.requestPermission()
                }
            }
        }
    }

    private func performCheckIn() async {
        isSubmitting = true
        errorMessage = nil

        do {
            let lat = locationManager.location?.latitude
            let lng = locationManager.location?.longitude

            try await APIClient.shared.requestVoid(
                .createCheckIn(
                    restaurantId: restaurant.id,
                    latitude: lat,
                    longitude: lng,
                    postId: nil
                )
            )

            withAnimation {
                showSuccess = true
            }

            // Dismiss after brief delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
