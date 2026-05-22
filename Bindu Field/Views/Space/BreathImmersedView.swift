import SwiftUI

/// Immersed breath-session screen for Akash. Mirrors SpaceImmersedView's
/// mechanics (the design called the existing screen "already correct" —
/// breath circle, phase word + count, gentle background, lock-screen
/// metadata, audio exclusivity) and extends with three Akash-specific
/// surfaces:
///
/// - Recognition statement surfaces once at ~45% through, fades after 4s.
/// - The session name + seed phrase anchor the bottom.
/// - Special-cue label (hum / ocean / double-pulse / active-phase) lives
///   just below the breath circle on the relevant phase.
/// - A `read` capsule in the bottom-right opens the Reading Space.
///
/// Driven by `JoinedBreathSession` so the Airtable spine + protocol
/// metadata are joined into a single value. The chakra-based ritual flow
/// keeps its own `SpaceImmersedView`.
struct BreathImmersedView: View {
    let session: JoinedBreathSession
    let durationMinutes: Int
    let onEnd: (Bool) -> Void          // true = completed naturally
    let onOpenReading: () -> Void

    @State private var store = PlayerStore.shared
    @State private var sessionStart: Date = Date()

    @Environment(\.binduTheme) private var theme

    private var totalDuration: TimeInterval { Double(durationMinutes * 60) }
    private var inhaleSec: Double { Double(session.inhale) }
    private var holdSec: Double { Double(session.hold) }
    private var exhaleSec: Double { Double(session.exhale) }
    private var cycleSec: Double { max(0.5, inhaleSec + holdSec + exhaleSec) }
    private var baseBeat: Float { session.beatHz }
    private var baseCarrier: Float { session.carrierHz }

    private var hueColor: Color {
        Color(hue: session.hue / 360, saturation: 0.55, brightness: 0.65)
    }
    private var phaseAccent: (BreathPhase) -> Color { { phase in
        switch phase {
        case .inhale:
            return Color(hue: session.hue / 360, saturation: 0.58, brightness: 0.65)
        case .hold:
            // Slight hue shift to mark the held breath without restating it
            return Color(hue: (session.hue + 35).truncatingRemainder(dividingBy: 360) / 360,
                         saturation: 0.52, brightness: 0.62)
        case .exhale:
            return Color(red: 0.78, green: 0.85, blue: 0.90).opacity(0.5)
        }
    } }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [hueColor.opacity(0.22), theme.bg],
                center: .center,
                startRadius: 80,
                endRadius: 700
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                let now = timeline.date
                let elapsed = now.timeIntervalSince(sessionStart)
                let remaining = max(0, totalDuration - elapsed)
                let cyclePosition = elapsed.truncatingRemainder(dividingBy: cycleSec)
                let (phase, phaseProgress, phaseRemaining) = computeBreath(cyclePosition: cyclePosition)
                let ringScale = ringScaleFor(phase: phase, progress: phaseProgress)

                content(
                    remaining: remaining,
                    elapsed: elapsed,
                    phase: phase,
                    phaseRemaining: phaseRemaining,
                    ringScale: ringScale
                )
                .onChange(of: phase) { _, newPhase in
                    let mod: Float = {
                        switch newPhase {
                        case .inhale: return 1.0
                        case .hold:   return 1.10
                        case .exhale: return 0.80
                        }
                    }()
                    store.setBeat(baseBeat * mod)
                }
                .onChange(of: remaining < 0.1) { _, ended in
                    if ended { onEnd(true) }
                }
            }
        }
        .onAppear {
            AudioExclusivityCoordinator.shared.request(.space)
            store.startBinaural(carrier: baseCarrier, beat: baseBeat)
            store.setGain(SettingsStore.shared.gain)
            NowPlayingService.shared.updateForChakra(
                sanskrit: session.name,
                english: session.intention.word.uppercased(),
                duration: totalDuration
            )
        }
        .onDisappear {
            store.stopBinaural()
            saveSession()
            NowPlayingService.shared.clear()
            AudioExclusivityCoordinator.shared.release(.space)
        }
        .onReceive(NotificationCenter.default.publisher(for: .binduSpaceStop)) { _ in
            onEnd(false)
        }
        .statusBarHidden()
    }

    // MARK: - Content

    @ViewBuilder
    private func content(remaining: TimeInterval, elapsed: TimeInterval, phase: BreathPhase, phaseRemaining: Double, ringScale: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top bar — close, timer
            HStack {
                Button(action: { onEnd(false) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(theme.subtle)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text(remaining.asPlaybackTime)
                    .font(.system(size: 13, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(theme.muted)
                    .padding(.trailing, 12)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer(minLength: 12)

            // Breath circle
            ZStack {
                Circle()
                    .stroke(hueColor.opacity(0.15), lineWidth: 1)
                    .frame(width: 280, height: 280)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [hueColor.opacity(0.50), hueColor.opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(ringScale)
                    .animation(.linear(duration: 0.1), value: ringScale)

                Circle()
                    .stroke(hueColor.opacity(0.75), lineWidth: 1.4)
                    .frame(width: 240, height: 240)
                    .scaleEffect(ringScale)
                    .animation(.linear(duration: 0.1), value: ringScale)

                VStack(spacing: 4) {
                    Text(specialOrDefaultLabel(phase))
                        .font(.system(size: 22, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(phaseAccent(phase))
                        .animation(.easeInOut(duration: 1.2), value: phase)
                    Text("\(Int(ceil(phaseRemaining)))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(theme.muted)
                }

                // Center dot
                Circle()
                    .fill(Color(hue: session.hue / 360, saturation: 0.72, brightness: 0.7))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hue: session.hue / 360, saturation: 0.68, brightness: 0.62), radius: 14)
                    .offset(y: 0)
                    .opacity(0)   // text takes the center; the dot lives in the radial gradient
            }

            // Special cue line — sits under the circle, only on the relevant phase
            if let cue = session.special, cueIsVisible(cue: cue, phase: phase) {
                Text(cue.cueLabel)
                    .font(.system(size: 11.5, design: .serif))
                    .italic()
                    .foregroundColor(hueColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 1.0), value: phase)
            }

            Spacer()

            // Mid-session recognition fade
            recognitionView(elapsed: elapsed)

            // Bottom — session name + seed
            VStack(spacing: 4) {
                Text(session.name)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(Color(hue: session.hue / 360, saturation: 0.40, brightness: 0.62).opacity(0.75))
                Text(session.seed)
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 8)

            HStack {
                Spacer()
                Button(action: onOpenReading) {
                    Text("READ")
                        .font(.system(size: 8.5, weight: .light, design: .monospaced))
                        .tracking(2.0)
                        .foregroundColor(theme.subtle.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func recognitionView(elapsed: TimeInterval) -> some View {
        let revealAt = totalDuration * 0.45
        let hideAt = revealAt + 4.0
        let visible = elapsed >= revealAt && elapsed < hideAt
        let opacity: Double = {
            if !visible { return 0 }
            let progress = (elapsed - revealAt) / 4.0
            // Fade in for the first second, hold, fade out the last second
            if progress < 0.25 { return progress * 4.0 * 0.55 }
            if progress > 0.75 { return (1.0 - progress) * 4.0 * 0.55 }
            return 0.55
        }()
        return Group {
            if let rec = session.recognitionStatement, !rec.isEmpty {
                Text(rec)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.text.opacity(opacity))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 340)
                    .allowsHitTesting(false)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Logic

    private func computeBreath(cyclePosition: Double) -> (BreathPhase, Double, Double) {
        if inhaleSec > 0 && cyclePosition < inhaleSec {
            return (.inhale, cyclePosition / inhaleSec, inhaleSec - cyclePosition)
        } else if holdSec > 0 && cyclePosition < inhaleSec + holdSec {
            let p = cyclePosition - inhaleSec
            return (.hold, p / holdSec, holdSec - p)
        } else {
            let exhaleStart = inhaleSec + holdSec
            let p = max(0, cyclePosition - exhaleStart)
            let safe = max(0.5, exhaleSec)
            return (.exhale, p / safe, safe - p)
        }
    }

    private func ringScaleFor(phase: BreathPhase, progress: Double) -> CGFloat {
        switch phase {
        case .inhale: return 0.70 + CGFloat(progress) * 0.50
        case .hold:   return 1.20
        case .exhale: return 1.20 - CGFloat(progress) * 0.50
        }
    }

    private func specialOrDefaultLabel(_ phase: BreathPhase) -> String {
        if let cue = session.special, let label = cue.phaseLabel(for: phase) {
            return label
        }
        return phase.defaultLabel
    }

    private func cueIsVisible(cue: BreathSpecialCue, phase: BreathPhase) -> Bool {
        switch cue {
        case .hum, .ocean:           return phase == .exhale
        case .doublePulse:           return phase == .inhale
        case .activePhase:           return phase == .inhale
        }
    }

    private func saveSession() {
        let elapsed = Date().timeIntervalSince(sessionStart)
        if elapsed < 5 { return }
        let completed = elapsed >= totalDuration - 1.0
        let archived = Session(
            id: UUID(),
            timestamp: sessionStart,
            type: .chakra,
            sourceID: String(session.id),
            displayName: session.name,
            secondaryLabel: session.intention.word,
            duration: elapsed,
            carrier: baseCarrier,
            beat: baseBeat,
            completed: completed
        )
        SessionStore.shared.save(archived)
    }
}
