import Foundation

enum BinduConfig {
    /// Resolves the streaming URL for a track via the existing model.
    /// `Track.audioURL` uses the track's own `baseURL` + `filename` — e.g.
    /// "https://aistrangegame.com/bindu/still.mp3" or
    /// "https://aistrangegame.com/tree-of-life/muladhara.mp3".
    /// Spec's hardcoded `track-{id}.mp3` convention does not match the
    /// existing hosting, so we go through the model instead.
    static func audioURL(for trackID: Int) -> URL? {
        guard let track = TrackData.all.first(where: { $0.id == trackID }) else { return nil }
        return track.audioURL
    }
}
