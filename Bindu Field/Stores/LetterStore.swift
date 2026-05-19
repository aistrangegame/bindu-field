import SwiftUI
import Observation

@MainActor
@Observable
final class LetterStore {
    static let shared = LetterStore()

    private(set) var letters: [Letter] = []
    private let storage = UserDefaultsCodable<[Letter]>(key: "binduLetters.v1")

    private init() {
        letters = storage.load() ?? []
    }

    func save(_ letter: Letter) {
        letters.insert(letter, at: 0)
        storage.save(letters)
    }

    func delete(_ letter: Letter) {
        letters.removeAll { $0.id == letter.id }
        try? FileManager.default.removeItem(at: letter.audioURL)
        storage.save(letters)
    }
}
