import Foundation
import Observation

/// Persistent record of which chakras the user has danced. Anything in
/// `dancedIDs` renders with orbit rings on the Map; anything composed but
/// not danced renders as `available`; everything else is locked.
@MainActor
@Observable
final class ChakraJourneyStore {
    static let shared = ChakraJourneyStore()

    private(set) var dancedIDs: Set<String> = []

    private let storage = UserDefaultsCodable<[String]>(key: "binduJourney.v1")

    private init() {
        if let raw = storage.load() {
            dancedIDs = Set(raw)
        }
    }

    /// Mark a chakra as danced. Idempotent — same id twice is a no-op.
    /// Persists synchronously.
    func markDanced(_ id: String) {
        let inserted = dancedIDs.insert(id).inserted
        if inserted {
            storage.save(Array(dancedIDs))
        }
    }

    /// Render state for a chakra: locked → not yet composed; available →
    /// composed but not danced; danced → in the journey.
    func state(for chakra: ChakraNode) -> ChakraNodeState {
        if !chakra.isComposed { return .locked }
        if dancedIDs.contains(chakra.id) { return .danced }
        return .available
    }

    /// Test / Settings: erase the journey. Not surfaced anywhere today.
    func clear() {
        dancedIDs = []
        storage.remove()
    }
}
