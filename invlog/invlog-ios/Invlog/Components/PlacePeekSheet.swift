import SwiftUI
@preconcurrency import NukeUI

/// Compact bottom sheet showing restaurant summary when tapping place name.
struct PlacePeekSheet: View {
    let restaurant: Restaurant
    let onViewFullProfile: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Drag indicator
            HStack { Spacer(); Capsule().fill(Color.brandBorder).frame(width: 36, height: 5); Spacer() }
                .padding(.top, 8)

            // Restaurant info row
            HStack(spacing: 12) {
                // Thumbnail
                LazyImage(url: restaurant.avatarUrl ?? restaurant.coverUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandBackground)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundColor(Color.brandTextTertiary)
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(InvlogTheme.heading(16))
                        .foregroundColor(Color.brandText)
                        .lineLimit(1)

                    if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                        Text(cuisines.joined(separator: " · "))
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Stats row
            HStack(spacing: 20) {
                if let rating = restaurant.avgRating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(InvlogTheme.body(13, weight: .semibold))
                        .foregroundColor(Color.brandSecondary)
                }

                Label("\(restaurant.checkinCount) check-ins", systemImage: "mappin.circle.fill")
                    .font(InvlogTheme.body(13, weight: .medium))
                    .foregroundColor(Color.brandTextSecondary)

                if restaurant.followerCount > 0 {
                    Label("\(restaurant.followerCount) followers", systemImage: "person.2.fill")
                        .font(InvlogTheme.body(13, weight: .medium))
                        .foregroundColor(Color.brandTextSecondary)
                }
            }

            // Action buttons
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onViewFullProfile()
                }
            } label: {
                Text("View Full Profile")
                    .font(InvlogTheme.body(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.brandCard)
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.hidden)
    }
}
