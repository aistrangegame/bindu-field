import SwiftUI

/// Akash — the breath space. Replaces the chakra-grid front door with an
/// intention grid; reads the 11 breath sessions (IDs 101–111) from
/// Airtable; preserves the existing immersed breath-circle mechanics in
/// `BreathImmersedView`; adds a screened gate for `safety == .screened`
/// sessions (today: 105 The Stoke) and a Reading Space (mirrors the music
/// Player's READING mode).
///
/// State machine (`Stage`):
///   intentions → subSelection → detail → screenedGate → immersed → reading
struct SpaceView: View {
    @State private var stage: Stage = .intentions
    @State private var intention: BreathIntention? = nil
    @State private var session: JoinedBreathSession? = nil
    @State private var duration: Int = {
        let chips = [3, 5, 10, 15]
        let configured = Int(SettingsStore.shared.defaultSessionDuration / 60)
        return chips.contains(configured) ? configured : 10
    }()
    @State private var store = BreathSessionStore.shared

    enum Stage: Equatable {
        case intentions
        case subSelection
        case detail
        case screenedGate
        case immersed
        case reading
    }

    var body: some View {
        ZStack {
            switch stage {
            case .intentions:
                IntentionGridView(onSelect: selectIntention)

            case .subSelection:
                if let intention {
                    SubSelectionView(
                        intention: intention,
                        onSelect: selectSession,
                        onBack: { stage = .intentions }
                    )
                } else {
                    IntentionGridView(onSelect: selectIntention)
                }

            case .detail:
                if let session {
                    SessionDetailView(
                        session: session,
                        onBegin: beginSession,
                        onBack: backFromDetail,
                        onReadMore: { stage = .reading }
                    )
                }

            case .screenedGate:
                if let session {
                    ScreenedGateView(
                        session: session,
                        onProceed: { stage = .immersed },
                        onChooseOther: { stage = .intentions }
                    )
                }

            case .immersed:
                if let session {
                    BreathImmersedView(
                        session: session,
                        durationMinutes: duration,
                        onEnd: { _ in stage = .intentions },
                        onOpenReading: { stage = .reading }
                    )
                }

            case .reading:
                if let session {
                    BreathReadingSpaceView(
                        session: session,
                        onBack: backFromReading
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: stage)
    }

    // MARK: - Transitions

    private func selectIntention(_ intent: BreathIntention) {
        intention = intent
        if intent.sessionIDs.count == 1, let id = intent.sessionIDs.first,
           let s = store.session(id: id) {
            session = s.joined()
            stage = .detail
        } else {
            stage = .subSelection
        }
    }

    private func selectSession(_ joined: JoinedBreathSession) {
        session = joined
        stage = .detail
    }

    private func beginSession(durationMinutes: Int) {
        duration = durationMinutes
        guard let s = session else { stage = .intentions; return }
        if s.safety == .screened {
            stage = .screenedGate
        } else {
            stage = .immersed
        }
    }

    private func backFromDetail() {
        if let intention, intention.sessionIDs.count > 1 {
            stage = .subSelection
        } else {
            stage = .intentions
        }
    }

    private func backFromReading() {
        // From reading, prefer to land back on detail if we came from it;
        // otherwise return to intentions.
        if session != nil {
            stage = .detail
        } else {
            stage = .intentions
        }
    }
}
