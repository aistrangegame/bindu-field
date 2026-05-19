import Foundation

enum BinduConfig {
    /// Resolves the streaming URL for a track from the current catalog.
    /// `Track.audioURL` is the full URL string supplied by Airtable.
    @MainActor
    static func audioURL(for trackID: Int) -> URL? {
        guard let track = CatalogStore.shared.tracks.first(where: { $0.id == trackID }) else { return nil }
        return URL(string: track.audioURL)
    }
}
