import SwiftUI
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let gainKey = "binduSettings.gain"
    private let durationKey = "binduSettings.defaultDuration"
    private let vizModeKey = "binduSettings.vizMode"

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

    private init() {
        let storedGain = UserDefaults.standard.object(forKey: gainKey) as? Float
        self.gain = storedGain ?? 0.04

        let storedDuration = UserDefaults.standard.object(forKey: durationKey) as? Double
        self.defaultSessionDuration = storedDuration ?? 600

        let storedVizMode = UserDefaults.standard.string(forKey: vizModeKey)
        self.vizMode = storedVizMode ?? "ensemble"
    }
}
