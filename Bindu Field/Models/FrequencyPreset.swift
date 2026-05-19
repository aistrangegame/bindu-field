import Foundation

/// A saved (carrier, beat) pair the user can recall from the Lab.
/// `isSystem` distinguishes the shipped defaults from user-saved entries
/// — system presets are not deletable and are not persisted (they live
/// in the catalogue below).
struct FrequencyPreset: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var carrierHz: Float
    var beatHz: Float
    var note: String?
    let createdAt: Date
    let isSystem: Bool

    static let systemPresets: [FrequencyPreset] = [
        FrequencyPreset(id: UUID(), name: "Earth Tone",
            carrierHz: 136.1, beatHz: 7.83,
            note: "Schumann resonance. The Earth's electromagnetic heartbeat.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Deep Delta",
            carrierHz: 136.1, beatHz: 1.5,
            note: "Below the dreaming threshold. Cellular restoration.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Theta Gate",
            carrierHz: 136.1, beatHz: 5.5,
            note: "The entry point. Between waking and sleep.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Creative",
            carrierHz: 174.0, beatHz: 7.0,
            note: "Low carrier, theta beat. Open and grounded simultaneously.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Presence",
            carrierHz: 432.0, beatHz: 10.0,
            note: "Alternative concert pitch. Relaxed alertness.",
            createdAt: .distantPast, isSystem: true),
    ]
}
