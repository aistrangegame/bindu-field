import Foundation

enum SessionType: String, Codable {
    case track
    case chakra
}

struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let type: SessionType
    let sourceID: String        // Track.id (stringified) or ChakraName.rawValue
    let displayName: String     // Track.verb or chakra Sanskrit name
    let secondaryLabel: String  // "Song — Artist" or chakra center (English)
    let duration: TimeInterval  // seconds
    let carrier: Float
    let beat: Float
    let completed: Bool         // ran to natural end vs stopped early
}
