import Foundation

/// On-disk MP3 cache for Field tracks.
///
/// Not `@MainActor` — downloads + filesystem walks shouldn't pin the UI
/// thread. Callers awaiting `fetch(...)` hop back to their actor as usual.
final class AudioCache: @unchecked Sendable {
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

    /// Maximum total cache size on disk. When `fetch` would push past this,
    /// LRU eviction trims to ~75% of the cap. Tuned for ~30 mp3s of typical
    /// chakra/music length (B18).
    private let maxCacheBytes: Int = 200 * 1024 * 1024  // 200 MB
    private let evictTargetRatio: Double = 0.75

    private init() {}

    // MARK: - Paths

    private var cacheDirectory: URL {
        // .first! is a documented platform invariant — every iOS sandbox
        // has a Caches directory. Trapping here surfaces a clear cause if
        // it ever doesn't (O23).
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Caches directory unavailable — sandbox is malformed")
        }
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

    // MARK: - Fetch / evict

    /// Returns a local file URL ready for playback. Downloads if not already cached.
    func fetch(trackID: Int) async throws -> URL {
        let local = localURL(for: trackID)
        if FileManager.default.fileExists(atPath: local.path) {
            // Touch atime so LRU eviction keeps recently-used tracks.
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: local.path
            )
            return local
        }

        guard let remote = await MainActor.run(body: { BinduConfig.audioURL(for: trackID) }) else {
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

        // B18: enforce the size cap after every successful write.
        evictIfOverCap()

        return local
    }

    /// Trim the cache to ~`evictTargetRatio` of the cap when over, evicting
    /// least-recently-modified files first.
    private func evictIfOverCap() {
        let dir = cacheDirectory
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: []
        ) else { return }

        struct Entry { let url: URL; let size: Int; let modified: Date }
        let infos: [Entry] = entries.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard let size = values?.fileSize, let modified = values?.contentModificationDate
            else { return nil }
            return Entry(url: url, size: size, modified: modified)
        }

        let totalBytes = infos.reduce(0) { $0 + $1.size }
        guard totalBytes > maxCacheBytes else { return }

        // Evict oldest first until we're under the target.
        let target = Int(Double(maxCacheBytes) * evictTargetRatio)
        var remaining = totalBytes
        let sorted = infos.sorted { $0.modified < $1.modified }
        for entry in sorted {
            if remaining <= target { break }
            try? FileManager.default.removeItem(at: entry.url)
            remaining -= entry.size
        }
    }

    // MARK: - Inspection / management (Settings UI)

    /// Total bytes currently cached. O(n) over the cache directory.
    func currentSizeBytes() -> Int {
        let dir = cacheDirectory
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }
        return entries.reduce(0) { acc, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return acc + size
        }
    }

    /// Clear all cached audio. Surfaced as a Settings row (G5).
    func purgeAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
