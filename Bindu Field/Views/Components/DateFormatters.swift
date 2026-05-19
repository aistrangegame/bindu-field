import Foundation

/// Shared date formatters used across Archive, Letter, and session UIs (O4).
/// Promoting them out of per-view privates means we instantiate each one
/// once instead of every render.
extension DateFormatter {
    /// "Tuesday, May 19, 2026" — used in ArchiveView day-group headers.
    static let archiveDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()

    /// "9:42 PM" — used in ArchiveView session rows.
    static let archiveTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    /// "May 19 · 9:42 PM" — used as the default title for a freshly
    /// recorded Letter when the user doesn't customize it.
    static let letterTitle: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d · h:mm a"
        return df
    }()
}
