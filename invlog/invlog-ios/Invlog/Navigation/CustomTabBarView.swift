import SwiftUI

// MARK: - Custom Tab Bar

struct CustomTabBarView: View {
    @Binding var selectedTab: MainTabView.Tab
    let onCreateTapped: () -> Void
    let unreadCount: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.brandBorder)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                tabButton(.feed, icon: "fork.knife", label: "Feed")
                tabButton(.search, icon: "magnifyingglass", label: "Discover")

                // Center: Orange create button
                Button(action: onCreateTapped) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.brandPrimary)
                            .frame(
                                width: InvlogTheme.TabBar.createButtonSize,
                                height: InvlogTheme.TabBar.createButtonSize
                            )
                            .shadow(
                                color: Color.brandPrimary.opacity(0.35),
                                radius: 8, y: 4
                            )

                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .offset(y: -8)
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
            VisualEffectBlur(blurStyle: .systemThinMaterial)
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
            selectedTab = tab
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

// MARK: - UIKit Blur Helper

struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
