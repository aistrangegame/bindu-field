import SwiftUI

/// Visual theme. The app is committed to the single `void` palette;
/// a theme picker would re-introduce `Theme` as a variant container.
struct Theme: Identifiable {
    let id: String
    let bg: Color
    let bg2: Color
    let text: Color
    let muted: Color
    let subtle: Color
    let accent: Color
    let gold: Color
    let border: Color
    let surface: Color
    let cornerRadius: CGFloat
    let hueShift: Double
}

enum ThemeData {
    static let void = Theme(
        id: "void",
        bg: Color(red: 0.008, green: 0.008, blue: 0.031),
        bg2: Color(red: 0.020, green: 0.020, blue: 0.059),
        text: Color(red: 0.961, green: 0.886, blue: 0.839),
        muted: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.55),
        subtle: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.28),
        accent: Color(red: 0.831, green: 0.392, blue: 0.361),
        gold: Color(red: 0.769, green: 0.659, blue: 0.384),
        border: Color.white.opacity(0.08),
        surface: Color.white.opacity(0.042),
        cornerRadius: 10,
        hueShift: 0
    )
}

// MARK: - Environment (O1)
//
// Views consume the active theme via `@Environment(\.binduTheme)` instead
// of redeclaring `private let theme = ThemeData.void` in every file. The
// default is `void` — switching themes app-wide is one `.environment(...)`
// at the RootView level.

private struct BinduThemeKey: EnvironmentKey {
    static let defaultValue: Theme = ThemeData.void
}

extension EnvironmentValues {
    var binduTheme: Theme {
        get { self[BinduThemeKey.self] }
        set { self[BinduThemeKey.self] = newValue }
    }
}
