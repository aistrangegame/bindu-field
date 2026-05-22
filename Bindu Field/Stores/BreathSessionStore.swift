import Foundation
import Observation

/// Airtable-backed cache of the 11 breath sessions (IDs 101–111). Same
/// shape as `CatalogStore` but separate because breath records carry a
/// leaner schema (no Artist / Element / Audio URL) and need their own
/// decode path.
///
/// Persisted under `binduBreathSessions.v1`. Refreshes from Airtable on
/// demand; a one-hour freshness window matches `CatalogStore`.
@MainActor
@Observable
final class BreathSessionStore {
    static let shared = BreathSessionStore()

    private(set) var sessions: [BreathSession] = []
    private(set) var isLoading: Bool = false
    private(set) var loadError: String? = nil
    private(set) var lastRefreshedAt: Date? = nil

    /// `true` when `sessions` came from the on-disk cache but the most
    /// recent network refresh failed.
    var isStaleFromCache: Bool {
        loadError != nil && !sessions.isEmpty
    }

    private let cacheKey = "binduBreathSessions.v1"
    private let timestampKey = "binduBreathSessions.v1.lastRefreshedAt"
    private let freshnessWindow: TimeInterval = 3600

    private init() {
        loadFromCache()
        if let raw = UserDefaults.standard.object(forKey: timestampKey) as? Double {
            lastRefreshedAt = Date(timeIntervalSince1970: raw)
        }
    }

    /// Refresh from Airtable. Skips the network if the cache is younger
    /// than `freshnessWindow` and `force` is false.
    func refresh(force: Bool = false) async {
        if !force,
           !sessions.isEmpty,
           let last = lastRefreshedAt,
           Date().timeIntervalSince(last) < freshnessWindow {
            return
        }

        isLoading = true
        loadError = nil
        do {
            let fetched = try await AirtableService.shared.fetchBreathSessions()
            if fetched.isEmpty && !sessions.isEmpty {
                loadError = "Breath sessions returned 0 records — keeping cached copy."
            } else {
                sessions = fetched
                saveToCache(fetched)
                let now = Date()
                lastRefreshedAt = now
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: timestampKey)
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    /// Find a session by Track ID. Returns nil if not loaded yet or
    /// missing from Airtable.
    func session(id: Int) -> BreathSession? {
        sessions.first { $0.id == id }
    }

    /// Sessions held by a given intention.
    func sessions(for intention: BreathIntention) -> [BreathSession] {
        intention.sessionIDs.compactMap { session(id: $0) }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([BreathSession].self, from: data)
        else { return }
        sessions = cached
    }

    private func saveToCache(_ sessions: [BreathSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
