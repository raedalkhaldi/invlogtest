import SwiftUI

extension Color {
    // Semantic colors that adapt to Light/Dark mode (HIG compliant)
    static let appBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let appLabel = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let appSeparator = Color(.separator)
    static let appGroupedBackground = Color(.systemGroupedBackground)

    // MARK: - Brand Colors (adaptive Light/Dark)
    static let brandPrimary = Color(hex: 0xE8590C)         // warm orange
    static let brandSecondary = Color(hex: 0xF59F00)        // golden yellow
    static let brandAccent = Color(hex: 0x12B886)           // teal/green

    // Adaptive colors — dark mode uses Instagram-like dark tones
    static let brandBackground = Color(light: Color(hex: 0xFAFAF8), dark: Color(hex: 0x000000))
    static let brandCard = Color(light: .white, dark: Color(hex: 0x1C1C1E))
    static let brandBorder = Color(light: Color(hex: 0xE8E5E0), dark: Color(hex: 0x38383A))
    static let brandText = Color(light: Color(hex: 0x1A1A1A), dark: Color(hex: 0xF5F5F5))
    static let brandTextSecondary = Color(light: Color(hex: 0x7C7C78), dark: Color(hex: 0xA0A0A0))
    static let brandTextTertiary = Color(light: Color(hex: 0xB0AEA8), dark: Color(hex: 0x6C6C70))

    // MARK: - Gamification Accents (adaptive)
    static let brandOrangeLight = Color(light: Color(hex: 0xFFF4EC), dark: Color(hex: 0x3D2010))
    static let brandYellowLight = Color(light: Color(hex: 0xFFF9DB), dark: Color(hex: 0x3D3410))
    static let brandTealLight = Color(light: Color(hex: 0xE6FCF5), dark: Color(hex: 0x0D3028))
    static let brandPurpleLight = Color(light: Color(hex: 0xF3F0FF), dark: Color(hex: 0x25203D))

    // MARK: - Hex Initializer
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    // MARK: - Adaptive Color Helper
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark: return UIColor(dark)
            default: return UIColor(light)
            }
        })
    }
}
