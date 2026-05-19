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
    let chakra: ChakraName?
    let type: TrackType
    let audioURL: String
    let youtubeID: String?
    let seed: String
    let carrierHz: Double
    let beatHz: Double
}
