import Foundation

enum BrainwaveState: String, Codable {
    case delta, theta, alpha
    case thetaAlpha = "theta-alpha"
}

enum ChakraName: String, Codable {
    case muladhara = "Muladhara"
    case svadhisthana = "Svadhisthana"
    case manipura = "Manipura"
    case anahata = "Anahata"
    case vishuddha = "Vishuddha"
    case ajna = "Ajna"
    case sahasrara = "Sahasrara"
    case aatma = "Aatma"
    case maya = "Maya"
}

enum TrackType: String, Codable {
    case chakra, music, meditate, family
}

struct Track: Codable, Hashable {
    let id: Int
    let verb: String
    let song: String
    let artist: String
    let element: String
    let state: BrainwaveState

    /// G15: optional chakra association. Retained as metadata for a future
    /// chakra-grouped Field filter / overlay; not consumed today. Airtable
    /// continues to be authoritative for `carrierHz` / `beatHz`.
    let chakra: ChakraName?

    let type: TrackType
    let audioURL: String

    /// G8: optional YouTube video ID. Intentionally retained for a future
    /// "watch on YouTube" affordance in `PlayerView`. Not surfaced today.
    let youtubeID: String?

    let seed: String
    let carrierHz: Double
    let beatHz: Double
}
