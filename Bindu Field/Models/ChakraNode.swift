import Foundation

/// Four systems of the 33-chakra map. Names match the original Sanskrit /
/// kabbalistic groupings; rendering treats them identically apart from the
/// locked-node radius (`tier` below).
enum ChakraSystem: String, Codable {
    case energy   // the 7 of the living spine
    case body     // 10 extended subtle-body points
    case mind     // 9 mental-field points
    case tree     // 7 Tree-of-Life sephirot
}

/// Rendering state of a node on the Map. `locked` covers chakras whose
/// dance has not yet been composed (no track); `available` exists in the
/// catalogue but the user has not danced it; `danced` is in their journey.
enum ChakraNodeState {
    case locked
    case available
    case danced
}

/// Static node data. Coordinates live in the source canvas (393 × 780)
/// and are scaled to the device on draw.
struct ChakraNode: Identifiable, Hashable {
    let id: String
    let name: String        // English / display name (e.g. "Anahata")
    let skt: String         // Devanagari Sanskrit
    let system: ChakraSystem
    let hue: Double         // 0–360
    let canvasX: Double     // 0–393
    let canvasY: Double     // 0–780
    let essence: String
    let tier: Int           // 1=energy, 2=body, 3=mind, 4=tree — controls locked-node radius

    var isComposed: Bool {
        ChakraRegistry.composedIDs.contains(id)
    }
}
