import AppKit

enum AppTheme: String, CaseIterable {
    case black
    case white

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        }
    }

    var appearance: NSAppearance? {
        NSAppearance(named: self == .black ? .darkAqua : .aqua)
    }
}

extension Notification.Name {
    static let compilePlusPlusThemeDidChange = Notification.Name("CompilePlusPlusThemeDidChange")
}

@MainActor
final class ThemeStore {
    static let shared = ThemeStore()

    private let defaultsKey = "CompilePlusPlusTheme"

    var current: AppTheme {
        didSet {
            guard current != oldValue else { return }
            UserDefaults.standard.set(current.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .compilePlusPlusThemeDidChange, object: current)
        }
    }

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: defaultsKey)
        current = AppTheme(rawValue: savedValue ?? "") ?? .black
    }
}

struct ThemePalette {
    let windowBackground: NSColor
    let panelBackground: NSColor
    let panelBorder: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let mutedText: NSColor
    let terminalBackground: NSColor
    let terminalForeground: NSColor
    let accent: NSColor

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .black:
            return ThemePalette(
                windowBackground: NSColor(srgbRed: 0.025, green: 0.032, blue: 0.045, alpha: 1),
                panelBackground: NSColor(srgbRed: 0.055, green: 0.067, blue: 0.09, alpha: 1),
                panelBorder: NSColor.white.withAlphaComponent(0.09),
                primaryText: NSColor.white.withAlphaComponent(0.92),
                secondaryText: NSColor.white.withAlphaComponent(0.72),
                mutedText: NSColor.white.withAlphaComponent(0.46),
                terminalBackground: NSColor(srgbRed: 0.035, green: 0.043, blue: 0.058, alpha: 1),
                terminalForeground: NSColor(srgbRed: 0.84, green: 0.88, blue: 0.93, alpha: 1),
                accent: NSColor(srgbRed: 0.26, green: 0.72, blue: 1.0, alpha: 1)
            )
        case .white:
            return ThemePalette(
                windowBackground: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.97, alpha: 1),
                panelBackground: NSColor.white,
                panelBorder: NSColor.black.withAlphaComponent(0.14),
                primaryText: NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1),
                secondaryText: NSColor(srgbRed: 0.18, green: 0.22, blue: 0.28, alpha: 1),
                mutedText: NSColor(srgbRed: 0.38, green: 0.43, blue: 0.50, alpha: 1),
                terminalBackground: NSColor(srgbRed: 0.985, green: 0.988, blue: 0.995, alpha: 1),
                terminalForeground: NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1),
                accent: NSColor(srgbRed: 0.0, green: 0.42, blue: 0.78, alpha: 1)
            )
        }
    }
}
