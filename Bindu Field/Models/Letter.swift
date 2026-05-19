import Foundation

struct Letter: Identifiable, Codable {
    let id: UUID
    var title: String
    let timestamp: Date
    let filename: String
    let durationSec: Double
    let stateLabel: String
    let carrier: Float
    let beat: Float

    var audioURL: URL {
        Letter.lettersDirectory.appendingPathComponent(filename)
    }

    /// Memoized — every `LetterRow` reads `letter.audioURL`, which used
    /// to re-stat the directory on every render (O10).
    static let lettersDirectory: URL = {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory unavailable — sandbox is malformed")
        }
        let dir = docs.appendingPathComponent("Letters", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
}
