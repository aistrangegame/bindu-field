import SwiftUI

/// Hosts the seven-step Consciousness Loop ceremony. Presented as a
/// fullScreenCover from the Player. The vocabulary background of the
/// current track renders behind every step (low-opacity, dimmed) so the
/// world the user is travelling in remains present.
struct LoopHostView: View {
    @State private var coord = ConsciousnessLoopCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#020208").ignoresSafeArea()

            // Vocabulary background (current track's world). Steps after
            // dance get a bit more presence; pre-roll/seed/offering stay
            // mostly black so the words breathe.
            if let track = coord.track {
                LoopBackground(track: track, state: coord.state)
                    .opacity(loopBackgroundOpacity)
                    .animation(.easeInOut(duration: 1.2), value: coord.state)
            }

            // Step content
            Group {
                switch coord.state {
                case .preRoll:
                    PreRollStepView(hue: coord.elementHue, onAdvance: { coord.advance() })
                case .seed:
                    SeedStepView(
                        hue: coord.elementHue,
                        question: seedText(for: coord.track),
                        sub: "it will be seen · returned to you",
                        onAdvance: { coord.advance() }
                    )
                case .offering:
                    OfferingStepView(
                        hue: coord.elementHue,
                        question: seedText(for: coord.track),
                        onOffer: { coord.advance() }
                    )
                case .dance:
                    DanceStepView(
                        hue: coord.elementHue,
                        words: coord.mirrorWords,
                        track: coord.track,
                        onAdvance: { coord.advance() }
                    )
                case .reveal:
                    RevealStepView(
                        hue: coord.elementHue,
                        word: coord.offeredWord,
                        onAdvance: { coord.advance() }
                    )
                case .fruit:
                    FruitStepView(
                        hue: coord.elementHue,
                        word: coord.offeredWord,
                        paragraphs: coord.fruitParagraphs,
                        onAdvance: { coord.advance() }
                    )
                case .lalita:
                    LalitaStepView(
                        line: coord.track?.lalitasPerspective?.trimmingCharacters(in: .whitespacesAndNewlines)
                            .nilIfEmpty
                            ?? "I see you. You have always been here.",
                        onClose: {
                            coord.advance()
                            close()
                        }
                    )
                case .idle, .done:
                    Color.clear.onAppear { close() }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: coord.state)

            // Step indicator top-left + chakra label top-right
            VStack {
                HStack(alignment: .top) {
                    LoopStepIndicator(hue: coord.elementHue, state: coord.state)
                    Spacer()
                    LoopCornerInfo(track: coord.track, hue: coord.elementHue)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                Spacer()
            }
            .allowsHitTesting(false)

            // Close affordance — always available, bottom-trailing.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: close) {
                        Text("close")
                            .font(.system(size: 9, weight: .light, design: .serif).italic())
                            .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.30))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var loopBackgroundOpacity: Double {
        switch coord.state {
        case .preRoll, .seed, .offering: return 0.0
        case .dance:                     return 0.55
        case .reveal:                    return 0.85
        case .fruit:                     return 0.45
        case .lalita:                    return 0.25
        default:                         return 0.0
        }
    }

    private func close() {
        coord.cancel()
        dismiss()
    }

    private func seedText(for track: Track?) -> String {
        // The seed question is the same across tracks today — the
        // architecture lets us swap it per-track later via a Score field
        // or a Track-level prompt without touching the views.
        "What word has been waiting in you?"
    }
}

// MARK: — Step indicator (top-left)

private struct LoopStepIndicator: View {
    let hue: Double
    let state: LoopState

    private let labels = ["PRE-ROLL", "SEED", "OFFERING", "DANCE", "REVEAL", "FRUIT", "LALITA"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(labels[min(state.stepIndex, labels.count - 1)])
                .font(.system(size: 7, weight: .light))
                .tracking(3.0)
                .textCase(.uppercase)
                .foregroundStyle(
                    Color(hue: hue / 360, saturation: 0.40, brightness: 0.58)
                        .opacity(0.45)
                )
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Rectangle()
                        .fill(barColor(forIndex: i))
                        .frame(width: i == state.stepIndex ? 14 : 4, height: 1)
                        .animation(.easeInOut(duration: 0.3), value: state)
                }
            }
        }
    }

    private func barColor(forIndex i: Int) -> Color {
        let idx = state.stepIndex
        if i < idx {
            return Color(hue: hue / 360, saturation: 0.45, brightness: 0.60).opacity(0.45)
        } else if i == idx {
            return Color(hue: hue / 360, saturation: 0.55, brightness: 0.68).opacity(0.80)
        } else {
            return Color(hex: "#F5E2D6").opacity(0.10)
        }
    }
}

// MARK: — Corner info (chakra label, mirror of Loop HTML's top-right)

private struct LoopCornerInfo: View {
    let track: Track?
    let hue: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let chakra = track?.chakra {
                Text(chakra.rawValue.uppercased())
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(2.8)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.40, brightness: 0.60)
                            .opacity(0.35)
                    )
            }
            if let track {
                Text(track.song)
                    .font(.system(size: 7.5, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.18))
            }
        }
    }
}

// MARK: — Background (vocabulary at low intensity)

/// The Loop's vocabulary background draws the track's element vocabulary
/// directly via the file-level `drawX(in:size:t:intens:)` helpers used by
/// the Player's Canvas. Renders behind a near-black veil — the music's
/// world is present but does not compete with the words.
private struct LoopBackground: View {
    let track: Track
    let state: LoopState

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                Canvas { gc, size in
                    let vocab = ElementVocabulary.forTrack(track)
                    let intens = 0.55
                    switch vocab {
                    case .earth:        drawEarth(in: gc, size: size, t: t, intens: intens)
                    case .water:        drawWater(in: gc, size: size, t: t, intens: intens)
                    case .fire:         drawFire(in: gc, size: size, t: t, intens: intens)
                    case .ether:        drawEther(in: gc, size: size, t: t, intens: intens)
                    case .constellation: drawConstellation(in: gc, size: size, t: t, intens: intens)
                    case .crown:        drawCrown(in: gc, size: size, t: t, intens: intens)
                    case .soul:         drawSoul(in: gc, size: size, t: t, intens: intens)
                    case .dissolution:  drawDissolution(in: gc, size: size, t: t, intens: intens)
                    case .meditate, .family:
                        drawAmbient(in: gc, size: size, t: t, intens: intens, hue: vocab.hue)
                    case .air:
                        // Air's full Cathedral is too much for a backdrop —
                        // use the ambient draw at the Air hue so the Loop
                        // sits on a calm field of Anahata rather than the
                        // peak-rendered Cathedral.
                        drawAmbient(in: gc, size: size, t: t, intens: intens, hue: 195)
                    }
                }
            }
            Color.black.opacity(0.55)
        }
        .ignoresSafeArea()
    }
}

// MARK: — Small helpers

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
