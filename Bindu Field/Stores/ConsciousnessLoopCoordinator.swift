import Foundation
import Observation
import SwiftUI

/// The seven steps of the Consciousness Loop, plus the bookends.
enum LoopState: CaseIterable {
    case idle
    case preRoll   // step 1 — breath
    case seed      // step 2 — the question
    case offering  // step 3 — offer a word
    case dance     // step 4 — mirror-word flash
    case reveal    // step 5 — peak word
    case fruit     // step 6 — three paragraphs
    case lalita    // step 7 — closing line
    case done

    /// Position in the 7-step bar. Returns 0 for non-step states.
    var stepIndex: Int {
        switch self {
        case .preRoll:  return 0
        case .seed:     return 1
        case .offering: return 2
        case .dance:    return 3
        case .reveal:   return 4
        case .fruit:    return 5
        case .lalita:   return 6
        default:        return 0
        }
    }
}

/// Coordinates the Loop's step machine and exposes the track-specific
/// content each step needs. The Loop is presented as a fullScreenCover
/// over the Player; the music continues underneath, so the coordinator
/// does not touch playback.
@MainActor
@Observable
final class ConsciousnessLoopCoordinator {
    static let shared = ConsciousnessLoopCoordinator()
    private init() {}

    private(set) var state: LoopState = .idle
    private(set) var track: Track? = nil
    private(set) var elementHue: Double = 195
    private(set) var mirrorWords: [String] = ConsciousnessLoopCoordinator.defaultMirrorWords
    private(set) var fruitParagraphs: [String] = []
    var offeredWord: String = ""

    /// Fire-once guard for the "Ceremony Sealed" App Activity write, so a
    /// sealed loop logs exactly one row. Reset on begin / cancel.
    private var didLogSeal = false

    /// Default mirror words used when a track has no authored `Score`
    /// or its score sets `mirrorWords = nil`. Five short verbs that the
    /// dance can flash for any element. Tuned to feel universal.
    static let defaultMirrorWords: [String] = [
        "return", "listen", "open", "soften", "trust"
    ]

    // MARK: — Lifecycle

    func begin(track: Track) {
        self.track = track
        self.elementHue = Color.binduHue(element: track.element)
        self.mirrorWords = Self.mirrorWordsForTrack(track)
        self.fruitParagraphs = []
        self.offeredWord = ""
        self.didLogSeal = false
        self.state = .preRoll
    }

    func cancel() {
        state = .idle
        track = nil
        offeredWord = ""
        fruitParagraphs = []
        didLogSeal = false
    }

    func advance() {
        switch state {
        case .idle:     state = .preRoll
        case .preRoll:  state = .seed
        case .seed:     state = .offering
        case .offering:
            // Lock the offered word and produce the fruit paragraphs that
            // reference it. If the user offered nothing, fall back to the
            // first default mirror word so the rest of the Loop still has
            // a noun to circle.
            if offeredWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                offeredWord = mirrorWords.first ?? "open"
            }
            fruitParagraphs = Self.fruitParagraphsForTrack(
                track,
                offeredWord: offeredWord
            )
            state = .dance
        case .dance:    state = .reveal
        case .reveal:   state = .fruit
        case .fruit:    state = .lalita
        case .lalita:
            state = .done
            // The ceremony is sealed — Field's one write to the shared
            // App Activity ledger. Fire-and-forget; never blocks the Loop.
            logCeremonySealed()
        case .done:     break
        }
    }

    /// Log a "Ceremony Sealed" App Activity row for the track this loop ran
    /// over. Links back to the catalog record when the rec id is known.
    private func logCeremonySealed() {
        guard !didLogSeal, let track else { return }
        didLogSeal = true
        let activityName = "\(track.verb) — \(track.song)"
        let detail = "Sealed the Loop over '\(track.verb)' — \(track.song) · \(track.artist)"
        let links = track.recordID.map { [$0] } ?? []
        Task {
            await AirtableService.shared.logAppActivity(
                activityName: activityName,
                activityType: "Ceremony Sealed",
                detail: detail,
                linkFieldRecordIDs: links
            )
        }
    }

    // MARK: — Per-track content

    private static func mirrorWordsForTrack(_ track: Track) -> [String] {
        // 1. Airtable-authored words win (the authorable source).
        if !track.mirrorWords.isEmpty {
            return track.mirrorWords
        }
        // 2. Hardcoded score fallback — keeps Track 27 correct even if its
        //    Airtable cell is blank or the catalog is offline.
        if let score = Score.forTrack(id: track.id),
           let words = score.mirrorWords,
           !words.isEmpty {
            return words
        }
        // 3. Universal default.
        return defaultMirrorWords
    }

    /// Three paragraphs of Fruit text. Prefer the Airtable `lyricalWordsReading`
    /// split on blank lines (up to three); otherwise generate a default
    /// trio that names the offered word.
    private static func fruitParagraphsForTrack(_ track: Track?, offeredWord: String) -> [String] {
        if let reading = track?.lyricalWordsReading,
           !reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let paras = reading
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if paras.count >= 3 {
                return Array(paras.prefix(3))
            }
            if paras.count == 2 {
                return [paras[0], paras[1], defaultClosing(for: offeredWord)]
            }
            if paras.count == 1 {
                return [paras[0], defaultMiddle(for: offeredWord), defaultClosing(for: offeredWord)]
            }
        }
        return [
            defaultOpening(for: offeredWord),
            defaultMiddle(for: offeredWord),
            defaultClosing(for: offeredWord),
        ]
    }

    private static func defaultOpening(for word: String) -> String {
        "\(word) arrived today in the space between heartbeats. the dance named what was already happening."
    }

    private static func defaultMiddle(for word: String) -> String {
        "you have offered a word of this root before. each time it comes back carrying what you were when you last let it go."
    }

    private static func defaultClosing(for word: String) -> String {
        "what \(word) opened cannot be closed."
    }
}
