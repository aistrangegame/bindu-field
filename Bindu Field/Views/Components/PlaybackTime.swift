import Foundation

extension TimeInterval {
    /// "M:SS" formatting used everywhere a playback clock is displayed
    /// (PlayerView, LetterPlaybackView, LetterRecordView, SpaceImmersedView).
    /// Negative values clamp to zero.
    var asPlaybackTime: String {
        let total = max(0, Int(self))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
