import SwiftUI

// MARK: - Custom Tab Bar

struct CustomTabBarView: View {
    @Binding var selectedTab: MainTabView.Tab
    let onCreateTapped: () -> Void
    let unreadCount: Int
    var onTabReselected: ((MainTabView.Tab) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.brandBorder)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                tabButton(.feed, icon: "fork.knife", label: "Feed")
                tabButton(.search, icon: "magnifyingglass", label: "Explore")

                // Center: Circular check-in button with gradient
                Button(action: onCreateTapped) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color(hex: 0xD44A08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: InvlogTheme.TabBar.createButtonSize,
                                height: InvlogTheme.TabBar.createButtonSize
                            )
                            .shadow(
                                color: Color.brandPrimary.opacity(0.45),
                                radius: 14, y: 6
                            )

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .offset(y: -14)
                .frame(maxWidth: .infinity)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Check In")

                tabButton(.notifications, icon: "bell", label: "Activity", badge: unreadCount)
                tabButton(.profile, icon: "person", label: "Profile")
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, InvlogTheme.TabBar.safeAreaBottom)
        }
        .background(
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .ignoresSafeArea(.all, edges: .bottom)
        )
    }

    private func tabButton(
        _ tab: MainTabView.Tab,
        icon: String,
        label: String,
        badge: Int = 0
    ) -> some View {
        Button {
            if selectedTab == tab {
                onTabReselected?(tab)
            } else {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == tab ? "\(icon).fill" : icon)
                        .font(.system(size: 20))

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(InvlogTheme.caption(9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -6)
                    }
                }

                Text(label)
                    .font(InvlogTheme.caption(10, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundColor(selectedTab == tab ? Color.brandPrimary : Color.brandTextTertiary)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(label)
    }
}

// MARK: - Color Hex (local for gradient)

private extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - UIKit Blur Helper

struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
