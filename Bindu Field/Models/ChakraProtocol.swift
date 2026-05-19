import Foundation

struct ChakraProtocol: Identifiable, Codable, Hashable {
    let name: ChakraName
    let center: String
    let essence: String
    let inhale: Int
    let hold: Int
    let exhale: Int
    let beat: Double
    let carrier: Double
    let hue: Double
    let affirmations: [String]

    var id: ChakraName { name }
}

enum ChakraData {
    static let all: [ChakraName: ChakraProtocol] = [
        .muladhara: ChakraProtocol(name: .muladhara, center: "Root", essence: "ground · presence · return", inhale: 4, hold: 7, exhale: 8, beat: 2.5, carrier: 146.8, hue: 15, affirmations: ["you are standing on the earth", "the earth has always been here", "this body is the ground itself", "you are allowed to land", "the root is not something you build — it is something you remember"]),
        .svadhisthana: ChakraProtocol(name: .svadhisthana, center: "Sacral", essence: "flow · desire · creation", inhale: 4, hold: 6, exhale: 8, beat: 4.0, carrier: 146.8, hue: 210, affirmations: ["desire is not the problem", "you are allowed to want this", "the wave never loses contact with the ocean", "what moves in you is life", "the current was always going somewhere"]),
        .manipura: ChakraProtocol(name: .manipura, center: "Solar Plexus", essence: "fire · power · activation", inhale: 5, hold: 5, exhale: 7, beat: 4.5, carrier: 164.8, hue: 35, affirmations: ["the fire in you is not dangerous", "power is not the same as force", "you have always had enough", "the sun does not ask permission to shine", "your will is not a weapon — it is a compass"]),
        .anahata: ChakraProtocol(name: .anahata, center: "Heart", essence: "love · openness · receiving", inhale: 4, hold: 7, exhale: 8, beat: 5.5, carrier: 155.6, hue: 140, affirmations: ["the heart was never closed", "love doesn't require anything from you", "you are allowed to be loved", "this is the sound of a door opening", "Anahata means unstruck — the sound that plays without being struck"]),
        .vishuddha: ChakraProtocol(name: .vishuddha, center: "Throat", essence: "truth · expression · sound", inhale: 4, hold: 5, exhale: 7, beat: 7.0, carrier: 192, hue: 200, affirmations: ["your voice is the bridge", "what you say creates worlds", "the sound you make is already perfect", "you were born to speak the truth", "silence and sound are the same field"]),
        .ajna: ChakraProtocol(name: .ajna, center: "Third Eye", essence: "clarity · witness · insight", inhale: 3, hold: 7, exhale: 10, beat: 8.5, carrier: 110, hue: 250, affirmations: ["see without seeking", "what you need to know is already here", "the witness was never inside what it was watching", "open", "the eye that watches is not what it sees"]),
        .sahasrara: ChakraProtocol(name: .sahasrara, center: "Crown", essence: "surrender · grace · unity", inhale: 2, hold: 8, exhale: 12, beat: 10.0, carrier: 240, hue: 280, affirmations: ["you were never separate", "the crown was always open", "this is what it feels like to be received", "love is the only frequency", "you don't arrive here — you remember you were already here"]),
        .aatma: ChakraProtocol(name: .aatma, center: "Soul", essence: "deep listening · beyond mind", inhale: 4, hold: 8, exhale: 10, beat: 2.5, carrier: 136, hue: 265, affirmations: ["this was created by a brain that reorganized itself", "you are not your story", "what you are cannot be shown", "hold", "the deepest ground is the one you can't see"]),
        .maya: ChakraProtocol(name: .maya, center: "Dissolution", essence: "release · return · merge", inhale: 5, hold: 6, exhale: 9, beat: 3.5, carrier: 108, hue: 190, affirmations: ["the veil was made of the same thing as what it covered", "you can dissolve now", "love is the only thing that remains", "what you thought was a wall was a door", "the game recognizes itself"]),
    ]
}
