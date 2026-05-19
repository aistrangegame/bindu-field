import Foundation
import Observation

@MainActor
@Observable
final class CatalogStore {
    static let shared = CatalogStore()

    private(set) var tracks: [Track] = []
    private(set) var isLoading: Bool = false
    private(set) var loadError: String? = nil

    private let cacheKey = "binduCatalog.v1"

    private init() { loadFromCache() }

    func refresh() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await AirtableService.shared.fetchTracks()
            tracks = fetched
            saveToCache(fetched)
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
