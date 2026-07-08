import SwiftUI
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let gainKey = "binduSettings.gain"
    private let durationKey = "binduSettings.defaultDuration"
    private let vizModeKey = "binduSettings.vizMode"
    private let themeModeKey = "binduSettings.themeMode"

    var gain: Float {
        didSet {
            UserDefaults.standard.set(gain, forKey: gainKey)
            // O11: while music is playing, DSPWire is the sole authority
            // for engine gain — its next tick (≤100 ms away) will multiply
            // its RMS curve by `settings.gain` anyway. Writing the engine
            // here would just be overwritten and risks a brief flicker.
            // For Lab / Letter / Space (no music, no DSPWire polling),
            // we still need to update the live tone.
            if !DSPWireService.shared.isMusicPlaying {
                PlayerStore.shared.setGain(gain)
            }
        }
    }

    var defaultSessionDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultSessionDuration, forKey: durationKey)
        }
    }

    /// Player visualization mode. `"ensemble"` (default) renders the full
    /// Cathedral + archetype layers + Bindu. `"singular"` renders only the
    /// Bindu Lissajous — the canonical reference visualization.
    /// Consumed by `VisualizerView` on every frame.
    var vizMode: String {
        didSet {
            UserDefaults.standard.set(vizMode, forKey: vizModeKey)
        }
    }

    /// App appearance. `"system"` (default) follows the device, `"light"`
    /// forces the warm-paper light theme, `"dark"` forces the void theme.
    /// Consumed by `RootView` to inject `\.binduTheme` + set
    /// `.preferredColorScheme`. The immersive Canvas scenes pin `void`
    /// regardless — see `Theme.swift`.
    var themeMode: String {
        didSet {
            UserDefaults.standard.set(themeMode, forKey: themeModeKey)
        }
    }

    /// The palette to inject app-wide for a given system color scheme.
    /// `"system"` resolves against the device's current scheme.
    func activeTheme(for systemScheme: ColorScheme) -> Theme {
        switch themeMode {
        case "light": return ThemeData.light
        case "dark":  return ThemeData.void
        default:      return systemScheme == .light ? ThemeData.light : ThemeData.void
        }
    }

    /// The `.preferredColorScheme` to apply — `nil` for `"system"` so the OS
    /// decides (and status-bar / system chrome follow along).
    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private init() {
        let storedGain = UserDefaults.standard.object(forKey: gainKey) as? Float
        self.gain = storedGain ?? 0.04

        let storedDuration = UserDefaults.standard.object(forKey: durationKey) as? Double
        self.defaultSessionDuration = storedDuration ?? 600

        let storedVizMode = UserDefaults.standard.string(forKey: vizModeKey)
        self.vizMode = storedVizMode ?? "ensemble"

        let storedThemeMode = UserDefaults.standard.string(forKey: themeModeKey)
        self.themeMode = storedThemeMode ?? "system"
    }
}
