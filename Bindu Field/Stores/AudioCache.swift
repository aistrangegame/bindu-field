import Foundation

@MainActor
final class AudioCache {
    static let shared = AudioCache()

    enum CacheError: LocalizedError {
        case downloadFailed(Error)
        case notFound
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let e): return "Download failed: \(e.localizedDescription)"
            case .notFound:              return "Audio not available."
            case .writeFailed:           return "Couldn't save audio file."
            }
        }
    }

    private init() {}

    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("BinduTracks", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func localURL(for trackID: Int) -> URL {
        cacheDirectory.appendingPathComponent("track-\(trackID).mp3")
    }

    func isCached(trackID: Int) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: trackID).path)
    }

    /// Returns a local file URL ready for playback. Downloads if not already cached.
    func fetch(trackID: Int) async throws -> URL {
        let local = localURL(for: trackID)
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }

        guard let remote = BinduConfig.audioURL(for: trackID) else {
            throw CacheError.notFound
        }

        let tempURL: URL
        let response: URLResponse
        do {
            (tempURL, response) = try await URLSession.shared.download(from: remote)
        } catch {
            throw CacheError.downloadFailed(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CacheError.notFound
        }

        if FileManager.default.fileExists(atPath: local.path) {
            try? FileManager.default.removeItem(at: local)
        }
        do {
            try FileManager.default.moveItem(at: tempURL, to: local)
        } catch {
            throw CacheError.writeFailed
        }

        return local
    }

    func purgeAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
