import Foundation
import Observation

@MainActor
@Observable
final class CatalogStore {
    static let shared = CatalogStore()

    private(set) var tracks: [Track] = []
    private(set) var isLoading: Bool = false
    private(set) var loadError: String? = nil

    /// Wall-clock timestamp of the last successful refresh. Read by the
    /// "refresh on launch" gate and surfaced in Settings (O18).
    private(set) var lastRefreshedAt: Date? = nil

    /// `true` when `tracks` came from the on-disk cache but the most
    /// recent network refresh failed. UIs use this to render a subtle
    /// "offline" indicator without hiding the catalog (G14).
    var isStaleFromCache: Bool {
        loadError != nil && !tracks.isEmpty
    }

    private let cacheKey = "binduCatalog.v1"
    private let timestampKey = "binduCatalog.v1.lastRefreshedAt"

    /// Skip the network refresh if the cache is younger than this. Tuned
    /// for "open the app several times a day, refresh in the background".
    private let freshnessWindow: TimeInterval = 3600  // 1 hour

    private init() {
        loadFromCache()
        if let raw = UserDefaults.standard.object(forKey: timestampKey) as? Double {
            lastRefreshedAt = Date(timeIntervalSince1970: raw)
        }
    }

    /// Refresh from Airtable. If the cache is fresh enough and `force` is
    /// false, no network call is made (O18).
    func refresh(force: Bool = false) async {
        if !force,
           !tracks.isEmpty,
           let last = lastRefreshedAt,
           Date().timeIntervalSince(last) < freshnessWindow {
            return
        }

        isLoading = true
        loadError = nil
        do {
            let fetched = try await AirtableService.shared.fetchTracks()
            // B13: never wipe a good cache with a successful-but-empty
            // response. An empty array is more likely a permissions issue
            // than a real "no tracks anymore".
            if fetched.isEmpty && !tracks.isEmpty {
                loadError = "Catalog returned 0 records — keeping cached copy."
            } else {
                tracks = fetched
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

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([Track].self, from: data)
        else { return }
        tracks = cached
    }

    private func saveToCache(_ tracks: [Track]) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
