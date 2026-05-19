import SwiftUI

struct SpaceImmersedView: View {
    let chakra: ChakraProtocol
    let durationMinutes: Int
    let onEnd: (Bool) -> Void  // true = completed naturally, false = user cancelled
    var ritualProgress: (current: Int, total: Int)? = nil

    @State private var store = PlayerStore.shared
    @State private var sessionStart: Date = Date()

    @Environment(\.binduTheme) private var theme

    enum BreathPhase: Equatable {
        case inhale, hold, exhale
        var label: String {
            switch self {
            case .inhale: return "inhale"
            case .hold:   return "hold"
            case .exhale: return "exhale"
            }
        }
    }

    private var totalDuration: TimeInterval { Double(durationMinutes * 60) }
    private var inhaleSec: Double { Double(chakra.inhale) }
    private var holdSec: Double { Double(chakra.hold) }
    private var exhaleSec: Double { Double(chakra.exhale) }
    private var cycleSec: Double { inhaleSec + holdSec + exhaleSec }
    private var baseBeat: Float { Float(chakra.beat) }
    private var baseCarrier: Float { Float(chakra.carrier) }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [chakra.color.opacity(0.25), theme.bg],
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

                content(remaining: remaining, phase: phase, phaseRemaining: phaseRemaining, ringScale: ringScale, elapsed: elapsed)
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
            store.startBinaural(carrier: baseCarrier, beat: baseBeat)
            store.setGain(SettingsStore.shared.gain)
            NowPlayingService.shared.updateForChakra(
                sanskrit: chakra.name.rawValue,
                english: chakra.center,
                duration: totalDuration
            )
        }
        .onDisappear {
            store.stopBinaural()
            saveSession()
            NowPlayingService.shared.clear()
        }
        .statusBarHidden()
    }

    private func saveSession() {
        let elapsed = Date().timeIntervalSince(sessionStart)
        if elapsed < 5 { return }
        let completed = elapsed >= totalDuration - 1.0
        let session = Session(
            id: UUID(),
            timestamp: sessionStart,
            type: .chakra,
            sourceID: chakra.name.rawValue,
            displayName: chakra.name.rawValue,  // Sanskrit (e.g. "Anahata")
            secondaryLabel: chakra.center,       // English (e.g. "Heart")
            duration: elapsed,
            carrier: baseCarrier,
            beat: baseBeat,
            completed: completed
        )
        SessionStore.shared.save(session)
    }

    @ViewBuilder
    private func content(remaining: TimeInterval, phase: BreathPhase, phaseRemaining: Double, ringScale: CGFloat, elapsed: TimeInterval) -> some View {
        VStack {
            HStack {
                if let prog = ritualProgress {
                    Text("step \(prog.current) of \(prog.total)")
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
                    Spacer().frame(width: 16)
                }
                Text(remaining.asPlaybackTime)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.muted)
                Spacer()
                Button(action: { onEnd(false) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(theme.muted)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            ZStack {
                Circle()
                    .stroke(chakra.color.opacity(0.15), lineWidth: 1)
                    .frame(width: 280, height: 280)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [chakra.color.opacity(0.5), chakra.color.opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(ringScale)
                    .animation(.linear(duration: 0.1), value: ringScale)

                Circle()
                    .stroke(chakra.color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 240, height: 240)
                    .scaleEffect(ringScale)
                    .animation(.linear(duration: 0.1), value: ringScale)

                VStack(spacing: 4) {
                    Text(phase.label)
                        .font(.system(size: 24, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("\(Int(ceil(phaseRemaining)))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(theme.muted)
                }
            }

            Spacer()

            Text(currentAffirmation(elapsed: elapsed))
                .font(.system(size: 17, design: .serif))
                .italic()
                .foregroundColor(theme.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: 340)

            Spacer()

            VStack(spacing: 4) {
                Text(chakra.name.rawValue)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
                Text(chakra.center)
                    .font(.system(size: 10))
                    .foregroundColor(theme.subtle)
                    .textCase(.uppercase)
                    .tracking(2)
            }
            .padding(.bottom, 40)
        }
    }

    private func computeBreath(cyclePosition: Double) -> (BreathPhase, Double, Double) {
        if cyclePosition < inhaleSec {
            return (.inhale, cyclePosition / inhaleSec, inhaleSec - cyclePosition)
        } else if cyclePosition < inhaleSec + holdSec {
            let p = cyclePosition - inhaleSec
            return (.hold, p / holdSec, holdSec - p)
        } else {
            let p = cyclePosition - inhaleSec - holdSec
            return (.exhale, p / exhaleSec, exhaleSec - p)
        }
    }

    private func ringScaleFor(phase: BreathPhase, progress: Double) -> CGFloat {
        switch phase {
        case .inhale: return 0.7 + CGFloat(progress) * 0.5
        case .hold:   return 1.2
        case .exhale: return 1.2 - CGFloat(progress) * 0.5
        }
    }

    private func currentAffirmation(elapsed: TimeInterval) -> String {
        let rotateEvery: Double = 20
        let index = Int(elapsed / rotateEvery) % chakra.affirmations.count
        return chakra.affirmations[index]
    }

}
