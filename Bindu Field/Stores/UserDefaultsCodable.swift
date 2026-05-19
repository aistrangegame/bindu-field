import Foundation

/// Tiny helper that encapsulates the JSON-in-UserDefaults pattern shared by
/// `SessionStore` and `LetterStore` (O5). The duplication wasn't large but
/// the encode/decode boilerplate was identical in both — this puts it in
/// one place so future stores don't reinvent it.
///
/// Usage:
///     private let storage = UserDefaultsCodable<[Session]>(key: "binduSessions.v1")
///     storage.load() ?? []
///     storage.save(sessions)
struct UserDefaultsCodable<T: Codable> {
    let key: String
    var defaults: UserDefaults = .standard

    func load() -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func remove() {
        defaults.removeObject(forKey: key)
    }
}
