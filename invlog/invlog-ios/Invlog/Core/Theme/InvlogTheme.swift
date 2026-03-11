import SwiftUI

enum InvlogTheme {

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Border Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }

    // MARK: - Card Constants

    enum Card {
        static let borderWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 14
    }

    // MARK: - Avatar Sizes

    enum Avatar {
        static let small: CGFloat = 32
        static let medium: CGFloat = 40
        static let large: CGFloat = 56
        static let profile: CGFloat = 80
        static let storyRing: CGFloat = 64
        static let storyInner: CGFloat = 56
    }

    // MARK: - Tab Bar

    enum TabBar {
        static let contentHeight: CGFloat = 56
        static let safeAreaBottom: CGFloat = 34
        static let createButtonSize: CGFloat = 52
    }

    // MARK: - Shadows

    static let cardShadowColor = Color.black.opacity(0.04)
    static let cardShadowRadius: CGFloat = 3
    static let cardShadowY: CGFloat = 1

    // MARK: - Typography (SF Rounded)

    static func heading(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func caption(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
