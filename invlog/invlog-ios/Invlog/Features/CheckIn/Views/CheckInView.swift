import SwiftUI
import CoreLocation
@preconcurrency import NukeUI

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
                    LazyImage(url: restaurant.avatarUrl) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "building.2")
                                .font(.system(size: 40))
                                .foregroundColor(Color.brandTextTertiary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
                    .accessibilityHidden(true)

                    Text(restaurant.name)
                        .font(InvlogTheme.heading(22, weight: .bold))
                        .foregroundColor(Color.brandText)
                        .multilineTextAlignment(.center)

                    if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                        Text(cuisines.joined(separator: " · "))
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                }

                // Location status
                if let location = locationManager.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(Color.brandAccent)
                        Text("Location detected")
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    .accessibilityLabel("Your location has been detected")
                } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Getting your location...")
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                }

                // Success feedback
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.brandAccent)
                        Text("Checked in successfully!")
                            .font(InvlogTheme.body(14, weight: .bold))
                            .foregroundColor(Color.brandAccent)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(InvlogTheme.caption(12))
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
                            .font(InvlogTheme.body(16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(showSuccess ? Color.brandAccent : Color.brandPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
                }
                .frame(minHeight: 44)
                .disabled(isSubmitting || showSuccess)
                .padding(.horizontal)
                .accessibilityLabel("Check in at \(restaurant.name)")
            }
            .padding()
            .invlogScreenBackground()
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

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
