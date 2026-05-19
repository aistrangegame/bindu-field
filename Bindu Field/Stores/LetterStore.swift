import SwiftUI
import Observation

@MainActor
@Observable
final class LetterStore {
    static let shared = LetterStore()

    private(set) var letters: [Letter] = []
    private let key = "binduLetters.v1"

    private init() { load() }

    func save(_ letter: Letter) {
        letters.insert(letter, at: 0)
        persist()
    }

    func delete(_ letter: Letter) {
        letters.removeAll { $0.id == letter.id }
        try? FileManager.default.removeItem(at: letter.audioURL)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(letters) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Letter].self, from: data) else { return }
        letters = decoded
    }
}
