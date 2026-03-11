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

    // MARK: - Brand Colors (Habitica x Notion)
    static let brandPrimary = Color(hex: 0xE8590C)         // warm orange
    static let brandSecondary = Color(hex: 0xF59F00)        // golden yellow
    static let brandAccent = Color(hex: 0x12B886)           // teal/green
    static let brandBackground = Color(hex: 0xFAFAF8)       // warm off-white
    static let brandCard = Color.white
    static let brandBorder = Color(hex: 0xE8E5E0)           // warm gray border
    static let brandText = Color(hex: 0x1A1A1A)             // near black
    static let brandTextSecondary = Color(hex: 0x7C7C78)
    static let brandTextTertiary = Color(hex: 0xB0AEA8)

    // MARK: - Gamification Accents
    static let brandOrangeLight = Color(hex: 0xFFF4EC)
    static let brandYellowLight = Color(hex: 0xFFF9DB)
    static let brandTealLight = Color(hex: 0xE6FCF5)
    static let brandPurpleLight = Color(hex: 0xF3F0FF)

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
}
