import SwiftUI
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let gainKey = "binduSettings.gain"
    private let durationKey = "binduSettings.defaultDuration"

    var gain: Float {
        didSet {
            UserDefaults.standard.set(gain, forKey: gainKey)
            // Update gain live on any currently playing tone
            PlayerStore.shared.setGain(gain)
        }
    }

    var defaultSessionDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultSessionDuration, forKey: durationKey)
        }
    }

    private init() {
        let storedGain = UserDefaults.standard.object(forKey: gainKey) as? Float
        self.gain = storedGain ?? 0.04

        let storedDuration = UserDefaults.standard.object(forKey: durationKey) as? Double
        self.defaultSessionDuration = storedDuration ?? 600
    }
}
