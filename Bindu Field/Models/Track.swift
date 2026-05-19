import Foundation

enum BrainwaveState: String, Codable {
    case delta, theta, alpha
    case thetaAlpha = "theta-alpha"
}

enum Element: String, Codable {
    case earth = "Earth"
    case water = "Water"
    case fire = "Fire"
    case air = "Air"
    case light = "Light"
    case crown = "Crown"
    case soul = "Soul"
    case dissolution = "Dissolution"
    case meditate = "Meditate"
    case family = "Family"
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

struct Track: Identifiable, Codable, Hashable {
    let id: Int
    let verb: String
    let song: String
    let artist: String
    let element: Element
    let state: BrainwaveState
    let chakra: ChakraName?
    let type: TrackType
    let filename: String
    let baseURL: String
    let youtubeID: String?
    let seed: String

    var audioURL: URL? { URL(string: "\(baseURL)\(filename).mp3") }
}

enum TrackData {
    static let bindu = "https://aistrangegame.com/bindu/"
    static let tree = "https://aistrangegame.com/tree-of-life/"

    static let all: [Track] = [
        Track(id: 23, verb: "press", song: "Iron", artist: "Woodkid", element: .earth, state: .delta, chakra: .muladhara, type: .chakra, filename: "muladhara", baseURL: tree, youtubeID: nil, seed: "You don't remember how you got here."),
        Track(id: 24, verb: "follow", song: "Crystallize", artist: "Lindsey Stirling", element: .water, state: .theta, chakra: .svadhisthana, type: .chakra, filename: "svadhisthana", baseURL: tree, youtubeID: nil, seed: "This song has no words. Neither did you, once."),
        Track(id: 25, verb: "build", song: "Powerful", artist: "Major Lazer & Ellie Goulding", element: .fire, state: .theta, chakra: .manipura, type: .chakra, filename: "manipura", baseURL: tree, youtubeID: nil, seed: "You think this song is about another person."),
        Track(id: 26, verb: "open", song: "Love Me Like You Do", artist: "Ellie Goulding", element: .air, state: .thetaAlpha, chakra: .anahata, type: .chakra, filename: "anahata", baseURL: tree, youtubeID: nil, seed: "This is the only song that talks to you."),
        Track(id: 27, verb: "speak", song: "The Sound of Silence", artist: "Disturbed", element: .air, state: .alpha, chakra: .vishuddha, type: .chakra, filename: "vishuddha", baseURL: tree, youtubeID: nil, seed: "Everything you're about to hear, you already know."),
        Track(id: 28, verb: "still", song: "Experience", artist: "Ludovico Einaudi", element: .light, state: .alpha, chakra: .ajna, type: .chakra, filename: "ajna", baseURL: tree, youtubeID: nil, seed: "This song has no words. It doesn't need them."),
        Track(id: 29, verb: "receive", song: "Golden", artist: "HUNTR/X", element: .crown, state: .alpha, chakra: .sahasrara, type: .chakra, filename: "sahasrara", baseURL: tree, youtubeID: nil, seed: "You've been hiding."),
        Track(id: 30, verb: "hold", song: "Aatma", artist: "Chase Hughes", element: .soul, state: .delta, chakra: .aatma, type: .chakra, filename: "aatma", baseURL: tree, youtubeID: "qgw6iho4XFM", seed: "Made by a brain that reorganized itself."),
        Track(id: 31, verb: "dissolve", song: "Love Is the Only Thing", artist: "Lost Frequencies", element: .dissolution, state: .theta, chakra: .maya, type: .chakra, filename: "maya", baseURL: tree, youtubeID: nil, seed: "You already know what this song is about."),
        Track(id: 1, verb: "still", song: "Sit Around The Fire", artist: "Jon Hopkins, Ram Dass & East Forest", element: .meditate, state: .delta, chakra: nil, type: .meditate, filename: "still", baseURL: bindu, youtubeID: "3G4kCi_ldr8", seed: "Sit down. The fire is already lit."),
        Track(id: 2, verb: "dream", song: "Dream", artist: "Alan Watts / Superposition", element: .meditate, state: .delta, chakra: nil, type: .meditate, filename: "dream", baseURL: bindu, youtubeID: "59DmUgOXpTY", seed: "If you could dream any dream, what would you dream?"),
        Track(id: 35, verb: "in shadow", song: "In Shadow — A Modern Odyssey", artist: "Lubomir Arsov", element: .meditate, state: .delta, chakra: nil, type: .meditate, filename: "in_shadow", baseURL: bindu, youtubeID: "j800SVeiS5I", seed: "The witness was never inside what it was watching."),
        Track(id: 36, verb: "kingdom", song: "Kingdom", artist: "Lubomir Arsov", element: .meditate, state: .theta, chakra: nil, type: .meditate, filename: "kingdom", baseURL: bindu, youtubeID: "MA3iscoypcY", seed: "The throne at the center of every kingdom is empty."),
        Track(id: 10, verb: "release", song: "Overthinker", artist: "INZO", element: .water, state: .theta, chakra: nil, type: .music, filename: "release", baseURL: bindu, youtubeID: "luQSQuCHtcI", seed: "What would you do if you stopped thinking about it?"),
        Track(id: 0, verb: "search", song: "Faded", artist: "Alan Walker", element: .meditate, state: .theta, chakra: nil, type: .music, filename: "search", baseURL: bindu, youtubeID: nil, seed: "Where are you now?"),
        Track(id: 4, verb: "rise", song: "Opus", artist: "Eric Prydz", element: .air, state: .alpha, chakra: nil, type: .music, filename: "rise", baseURL: bindu, youtubeID: nil, seed: "What would you build if it didn't need to last?"),
        Track(id: 5, verb: "light", song: "A Sky Full of Stars", artist: "Coldplay", element: .light, state: .alpha, chakra: nil, type: .music, filename: "light", baseURL: bindu, youtubeID: nil, seed: "What do you see when you finally look up?"),
        Track(id: 8, verb: "howl", song: "Howling", artist: "RY X", element: .fire, state: .delta, chakra: nil, type: .music, filename: "howl", baseURL: bindu, youtubeID: nil, seed: "What sound are you holding in?"),
        Track(id: 14, verb: "ground", song: "Earth", artist: "Mogli", element: .earth, state: .delta, chakra: nil, type: .music, filename: "ground", baseURL: bindu, youtubeID: nil, seed: "What would hold you if you stopped holding yourself?"),
        Track(id: 33, verb: "before", song: "Genesis", artist: "Justice", element: .meditate, state: .delta, chakra: nil, type: .music, filename: "before", baseURL: bindu, youtubeID: nil, seed: "What was here before you arrived?"),
        Track(id: 34, verb: "purity", song: "Where'd You Go + Thunderclouds", artist: "Fort Minor / LSD", element: .family, state: .theta, chakra: nil, type: .family, filename: "purity", baseURL: bindu, youtubeID: nil, seed: "You turn nouns into verbs."),
        Track(id: 22, verb: "numb", song: "Habits (Stay High)", artist: "Tove Lo (Hippie Sabotage Remix)", element: .water, state: .delta, chakra: nil, type: .music, filename: "numb", baseURL: bindu, youtubeID: nil, seed: "What are you staying high enough to not feel?"),
    ]
}
