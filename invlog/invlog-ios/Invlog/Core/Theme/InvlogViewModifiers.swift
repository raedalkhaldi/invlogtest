import SwiftUI

// MARK: - Card Modifier

struct InvlogCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
            // No border overlay — cleaner card style
            .shadow(
                color: InvlogTheme.cardShadowColor,
                radius: InvlogTheme.cardShadowRadius,
                x: 0, y: InvlogTheme.cardShadowY
            )
    }
}

// MARK: - Primary Button Style (contrasting bg + text)

struct InvlogPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InvlogTheme.body(15, weight: .bold))
            .foregroundColor(Color.brandBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandText)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Secondary Button Style (outline)

struct InvlogSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InvlogTheme.body(15, weight: .bold))
            .foregroundColor(Color.brandText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Accent Button Style (orange bg, white text — full capsule like Stitch)

struct InvlogAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InvlogTheme.body(16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.brandPrimary, Color(hex: 0xD44A08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.brandPrimary.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Filter Pill Style

struct InvlogFilterPillStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InvlogTheme.caption(14, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isActive ? Color.brandText : Color.brandCard)
            .foregroundColor(isActive ? Color.brandBackground : Color.brandTextSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : Color.brandBorder, lineWidth: 1)
            )
    }
}

// MARK: - Color Hex (local for gradients)

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

// MARK: - View Extensions

extension View {
    func invlogCard() -> some View {
        modifier(InvlogCardModifier())
    }

    func invlogScreenBackground() -> some View {
        self.background(Color.brandBackground.ignoresSafeArea())
    }
}
