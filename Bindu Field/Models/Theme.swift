import SwiftUI

/// Visual theme. Two palettes ship today — the canonical dark `void` and a
/// warm-paper `light`. Views read the active one via `@Environment(\.binduTheme)`
/// (injected once at `RootView` from `SettingsStore.activeTheme`). The immersive
/// Canvas scenes (Field, Map tree, Player visualizer, Loop, breath rings) pin
/// `ThemeData.void` explicitly so they stay dark regardless of the app theme.
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

    /// `true` when this is a light palette — lets a view branch on brightness
    /// (e.g. choose `Color.black` vs `Color.white` overlays) without hardcoding
    /// a palette id.
    var isLight: Bool { id == "light" }
}

enum ThemeData {
    static let void = Theme(
        id: "void",
        bg: Color(red: 0.008, green: 0.008, blue: 0.031),
        bg2: Color(red: 0.020, green: 0.020, blue: 0.059),
        text: Color(red: 0.961, green: 0.886, blue: 0.839),
        // Contrast overhaul: secondary text was too faint on device.
        // muted 0.55 → 0.68, subtle 0.28 → 0.40. These two tokens back
        // ~40 section labels / secondary lines across the app.
        muted: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.68),
        subtle: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.40),
        accent: Color(red: 0.831, green: 0.392, blue: 0.361),
        gold: Color(red: 0.769, green: 0.659, blue: 0.384),
        border: Color.white.opacity(0.10),
        surface: Color.white.opacity(0.05),
        cornerRadius: 10,
        hueShift: 0
    )

    /// Warm-paper light palette for the informational / reading surfaces
    /// (Settings, Archive, AKASH detail + Reading, Letter, Map detail, Ritual
    /// setup). Same coral accent + gold; text inverts to a warm near-black and
    /// `surface`/`border` become dark-on-light. Token opacities match `void`
    /// so the same secondary-text call sites stay legible in both modes.
    static let light = Theme(
        id: "light",
        bg: Color(red: 0.965, green: 0.949, blue: 0.925),   // warm paper
        bg2: Color(red: 0.945, green: 0.925, blue: 0.898),
        text: Color(red: 0.114, green: 0.098, blue: 0.078),  // warm near-black
        muted: Color(red: 0.114, green: 0.098, blue: 0.078).opacity(0.68),
        subtle: Color(red: 0.114, green: 0.098, blue: 0.078).opacity(0.40),
        accent: Color(red: 0.760, green: 0.310, blue: 0.278),  // coral, a touch deeper for contrast on paper
        gold: Color(red: 0.639, green: 0.522, blue: 0.259),
        border: Color.black.opacity(0.12),
        surface: Color.black.opacity(0.05),
        cornerRadius: 10,
        hueShift: 0
    )
}

// MARK: - Environment (O1)
//
// Views consume the active theme via `@Environment(\.binduTheme)` instead
// of redeclaring `private let theme = ThemeData.void` in every file. The
// default is `void`; `RootView` injects `SettingsStore.activeTheme` so a
// theme switch is one `.environment(...)` at the root.

private struct BinduThemeKey: EnvironmentKey {
    static let defaultValue: Theme = ThemeData.void
}

extension EnvironmentValues {
    var binduTheme: Theme {
        get { self[BinduThemeKey.self] }
        set { self[BinduThemeKey.self] = newValue }
    }
}
