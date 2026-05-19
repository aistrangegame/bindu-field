import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [Session] = []
    private let storage = UserDefaultsCodable<[Session]>(key: "binduSessions.v1")

    private init() {
        sessions = storage.load() ?? []
    }

    func save(_ session: Session) {
        sessions.insert(session, at: 0)  // newest first
        storage.save(sessions)
    }

    func clearAll() {
        sessions = []
        storage.save(sessions)
    }
}
