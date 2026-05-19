import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [Session] = []
    private let key = "binduSessions.v1"

    private init() { load() }

    func save(_ session: Session) {
        sessions.insert(session, at: 0)  // newest first
        persist()
    }

    func clearAll() {
        sessions = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Session].self, from: data) else { return }
        sessions = decoded
    }
}
