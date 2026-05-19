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

    static var lettersDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Letters", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
