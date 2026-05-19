import Foundation
import Observation

/// User-defined frequency presets persisted alongside the shipped
/// system catalogue. Mirrors the LetterStore / SessionStore pattern:
/// `@MainActor @Observable` singleton, JSON-in-UserDefaults via
/// `UserDefaultsCodable`.
@MainActor
@Observable
final class PresetStore {
    static let shared = PresetStore()

    private(set) var userPresets: [FrequencyPreset] = []
    private let storage = UserDefaultsCodable<[FrequencyPreset]>(key: "binduPresets.v1")

    private init() {
        userPresets = storage.load() ?? []
    }

    /// System catalogue first, then user-saved (newest first since `save`
    /// inserts at index 0).
    var allPresets: [FrequencyPreset] {
        FrequencyPreset.systemPresets + userPresets
    }

    func save(name: String, carrierHz: Float, beatHz: Float, note: String? = nil) {
        let preset = FrequencyPreset(
            id: UUID(),
            name: name,
            carrierHz: carrierHz,
            beatHz: beatHz,
            note: note,
            createdAt: Date(),
            isSystem: false
        )
        userPresets.insert(preset, at: 0)
        storage.save(userPresets)
    }

    func delete(_ preset: FrequencyPreset) {
        guard !preset.isSystem else { return }
        userPresets.removeAll { $0.id == preset.id }
        storage.save(userPresets)
    }
}
