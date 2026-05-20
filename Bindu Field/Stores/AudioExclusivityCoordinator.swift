import Foundation
import Observation

/// Ownership token for the currently-rendering audio source. Two
/// independent code paths used to be able to render audio simultaneously
/// (a Lab binaural tone over a Field track), which produced overlapping
/// carriers and made the gain stack incoherent. This coordinator
/// serializes ownership so a new source explicitly evicts the prior one.
enum AudioSource {
    case none
    case track    // TrackPlaybackService (Field, Map, Oracle, MiniPlayer)
    case lab      // BinauralEngine direct (LabView)
    case space    // SpaceImmersedView standalone
    case ritual   // SpaceImmersedView under RitualRunningView
}

@MainActor
@Observable
final class AudioExclusivityCoordinator {
    static let shared = AudioExclusivityCoordinator()

    private(set) var activeSource: AudioSource = .none

    private init() {}

    /// Claim audio for the given source. If a different source is already
    /// active, evict it (Track stops via PlayerStore; the immersive sources
    /// listen for their stop notifications below).
    func request(_ source: AudioSource) {
        guard source != activeSource else { return }
        let prior = activeSource
        activeSource = source

        switch prior {
        case .track:
            // PlayerStore.stop tears down both engines + the wire + Performer
            // and closes the player modal. Same as user pressing END SESSION.
            PlayerStore.shared.stop(completed: false)
        case .lab:
            NotificationCenter.default.post(name: .binduLabStop, object: nil)
        case .space:
            NotificationCenter.default.post(name: .binduSpaceStop, object: nil)
        case .ritual:
            NotificationCenter.default.post(name: .binduRitualStop, object: nil)
        case .none:
            break
        }
    }

    /// Release the source if it currently owns audio. Idempotent — a
    /// release for a non-active source is a no-op so views can call this
    /// freely from onDisappear without checking who's active.
    func release(_ source: AudioSource) {
        if activeSource == source { activeSource = .none }
    }
}

extension Notification.Name {
    /// Posted by `AudioExclusivityCoordinator` when a new source is
    /// requested while Lab binaural is active. `LabView` resets its
    /// local `isPlaying` flag in response.
    static let binduLabStop = Notification.Name("BinduLabStop")

    /// Posted when a new source is requested while a standalone Space
    /// session is active. `SpaceImmersedView` ends via `onEnd(false)`.
    static let binduSpaceStop = Notification.Name("BinduSpaceStop")

    /// Posted when a new source is requested while a Ritual is active.
    /// `SpaceImmersedView` (under `RitualRunningView`) ends via
    /// `onEnd(false)`, which cascades the ritual's `onEnd` callback.
    static let binduRitualStop = Notification.Name("BinduRitualStop")
}
