import SwiftUI

/// Tabbed bottom sheet for the + create button.
/// Shows two tabs: Check In and Trips.
struct CreateOptionsSheet: View {
    @Binding var showCreatePost: Bool
    @Binding var showCreateTrip: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: CreateTab = .checkIn

    enum CreateTab: String, CaseIterable {
        case checkIn = "Check In"
        case trips = "Trips"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Segmented picker
            HStack(spacing: 0) {
                ForEach(CreateTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab == .checkIn ? "mappin.and.ellipse" : "map")
                                .font(.system(size: 22))
                            Text(tab.rawValue)
                                .font(InvlogTheme.body(14, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? Color.brandPrimary : Color.brandTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab
                                ? Color.brandOrangeLight
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Content
            VStack(spacing: 12) {
                if selectedTab == .checkIn {
                    Text("Share your food experience")
                        .font(InvlogTheme.body(15))
                        .foregroundColor(Color.brandTextSecondary)

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCreatePost = true
                        }
                    } label: {
                        Text("Start Check In")
                    }
                    .buttonStyle(InvlogAccentButtonStyle())
                    .padding(.horizontal, 20)
                } else {
                    Text("Plan your food journey")
                        .font(InvlogTheme.body(15))
                        .foregroundColor(Color.brandTextSecondary)

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCreateTrip = true
                        }
                    } label: {
                        Text("Create Trip")
                    }
                    .buttonStyle(InvlogAccentButtonStyle())
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.brandCard)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }
}
