import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @AppStorage("appearanceMode") var mode: AppearanceMode = .light

    var preferredColorScheme: ColorScheme? {
        mode.colorScheme
    }
}
