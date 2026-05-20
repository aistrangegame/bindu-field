import SwiftUI

// MARK: — Step 1 · Pre-roll (breath ring)

/// Five-and-a-half-second breath ring. After one full cycle, the
/// "tap to enter" affordance fades in. The breath ring is the only
/// step rendered before the music-world starts bleeding through.
struct PreRollStepView: View {
    let hue: Double
    let onAdvance: () -> Void

    @State private var showTap = false

    var body: some View {
        ZStack {
            TimelineView(.animation) { context in
                Canvas { gc, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let cx = size.width / 2
                    let cy = size.height / 2

                    // Breath cycle 5.5s; smoothstep on the half-phase.
                    let cycle = t.truncatingRemainder(dividingBy: 5.5) / 5.5
                    let inhale = cycle < 0.5
                    let pct = inhale ? cycle / 0.5 : (1 - cycle) / 0.5
                    let smooth = pct < 0.5 ? 2 * pct * pct : 1 - 2 * (1 - pct) * (1 - pct)
                    let r = 56 + 42 * smooth

                    // Outer aura
                    let aura = Gradient(stops: [
                        .init(
                            color: Color(hue: hue / 360, saturation: 0.55, brightness: 0.65)
                                .opacity(0.15 * smooth + 0.05),
                            location: 0
                        ),
                        .init(color: .clear, location: 1.0),
                    ])
                    gc.fill(
                        Path(ellipseIn: CGRect(x: cx - r * 1.8, y: cy - r * 1.8, width: r * 3.6, height: r * 3.6)),
                        with: .radialGradient(
                            aura,
                            center: CGPoint(x: cx, y: cy),
                            startRadius: r * 0.6,
                            endRadius: r * 1.8
                        )
                    )

                    // Main ring
                    gc.stroke(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                        with: .color(
                            Color(hue: hue / 360, saturation: 0.55, brightness: 0.68)
                                .opacity(0.45 + 0.25 * smooth)
                        ),
                        lineWidth: 1.2
                    )

                    // Inner ring
                    let ir = r * 0.66
                    gc.stroke(
                        Path(ellipseIn: CGRect(x: cx - ir, y: cy - ir, width: ir * 2, height: ir * 2)),
                        with: .color(
                            Color(hue: hue / 360, saturation: 0.50, brightness: 0.62)
                                .opacity(0.12 + 0.08 * smooth)
                        ),
                        lineWidth: 0.7
                    )

                    // 4 cardinal ticks
                    for i in 0..<4 {
                        let ang = Double(i) * .pi / 2 - .pi / 2
                        let inner = CGPoint(x: cx + cos(ang) * (r + 8), y: cy + sin(ang) * (r + 8))
                        let outer = CGPoint(x: cx + cos(ang) * (r + 14), y: cy + sin(ang) * (r + 14))
                        var tick = Path()
                        tick.move(to: inner)
                        tick.addLine(to: outer)
                        gc.stroke(
                            tick,
                            with: .color(
                                Color(hue: hue / 360, saturation: 0.40, brightness: 0.60)
                                    .opacity(0.20)
                            ),
                            lineWidth: 0.7
                        )
                    }

                    // Breath arc progress (full circle in 5.5s)
                    let arcEnd = cycle * .pi * 2 - .pi / 2
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: r + 4,
                        startAngle: .radians(-.pi / 2),
                        endAngle: .radians(arcEnd),
                        clockwise: false
                    )
                    gc.stroke(
                        arc,
                        with: .color(
                            Color(hue: hue / 360, saturation: 0.60, brightness: 0.72)
                                .opacity(0.35 + 0.2 * smooth)
                        ),
                        lineWidth: 1.5
                    )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Text("BREATHE")
                    .font(.system(size: 8, weight: .light))
                    .tracking(5.2)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.40, brightness: 0.62)
                            .opacity(0.45)
                    )
                    .padding(.bottom, 60)

                Text("tap to enter")
                    .font(.system(size: 8, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(showTap ? 0.32 : 0))
                    .padding(.bottom, 48)
            }
            .animation(.easeIn(duration: 1.5), value: showTap)
        }
        .contentShape(Rectangle())
        .onTapGesture { if showTap { onAdvance() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                showTap = true
            }
        }
    }
}

// MARK: — Step 2 · Seed (the question)

struct SeedStepView: View {
    let hue: Double
    let question: String
    let sub: String
    let onAdvance: () -> Void

    @State private var phase = 0

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Text(question)
                    .font(.system(size: 28, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 38)
                    .opacity(phase >= 1 ? 1 : 0)
                    .offset(y: phase >= 1 ? 0 : 8)
                    .animation(.easeOut(duration: 1.4), value: phase)

                Text(sub)
                    .font(.system(size: 13, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.38))
                    .opacity(phase >= 2 ? 1 : 0)
                    .animation(.easeOut(duration: 1.8), value: phase)
            }

            VStack {
                Spacer()
                Text("tap to offer")
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(3.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(phase >= 2 ? 0.30 : 0))
                    .padding(.bottom, 80)
                    .animation(.easeOut(duration: 2.0), value: phase)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if phase >= 2 { onAdvance() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { phase = 2 }
        }
    }
}

// MARK: — Step 3 · Offering (the word)

struct OfferingStepView: View {
    let hue: Double
    let question: String
    let onOffer: () -> Void

    @State private var coord = ConsciousnessLoopCoordinator.shared
    @FocusState private var focused: Bool

    private var trimmed: String {
        coord.offeredWord.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var done: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Seed reminder — drifted up, dim.
            Text(question)
                .font(.system(size: 13, weight: .light, design: .serif).italic())
                .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.18))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 60)
                .padding(.horizontal, 44)

            VStack(alignment: .leading, spacing: 0) {
                Text("OFFER A WORD")
                    .font(.system(size: 8, weight: .light))
                    .tracking(3.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.40, brightness: 0.60)
                            .opacity(0.40)
                    )
                    .padding(.bottom, 14)

                TextField("", text: $coord.offeredWord)
                    .focused($focused)
                    .font(.system(size: 38, weight: .light, design: .serif).italic())
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.55, brightness: 0.72)
                            .opacity(0.95)
                    )
                    .tint(Color(hue: hue / 360, saturation: 0.55, brightness: 0.70).opacity(0.7))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        if done { onOffer() }
                    }

                Rectangle()
                    .fill(Color(hue: hue / 360, saturation: 0.40, brightness: 0.55).opacity(0.25))
                    .frame(height: 1)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 44)

            Button(action: { if done { onOffer() } }) {
                Text("OFFER")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.50, brightness: 0.68)
                            .opacity(done ? 0.75 : 0.25)
                    )
                    .padding(.horizontal, 44).padding(.vertical, 15)
                    .overlay(
                        Capsule()
                            .stroke(
                                Color(hue: hue / 360, saturation: 0.40, brightness: 0.52)
                                    .opacity(done ? 0.45 : 0.20),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!done)
            .padding(.top, 52)

            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: — Step 4 · Dance (mirror words flash)

struct DanceStepView: View {
    let hue: Double
    let words: [String]
    let track: Track?
    let onAdvance: () -> Void

    @State private var wordIndex = -1
    @State private var wordVisible = false
    @State private var dimmed = false
    @State private var hasFlashed = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black
                .opacity(dimmed ? 0.55 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.15), value: dimmed)

            if wordIndex >= 0 {
                Text(currentWord)
                    .font(.system(size: isConsonant ? 56 : 68, weight: .light, design: .serif).italic())
                    .tracking(isConsonant ? 6 : -0.6)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.58, brightness: 0.74)
                            .opacity(0.92)
                    )
                    .shadow(
                        color: Color(hue: hue / 360, saturation: 0.55, brightness: 0.65).opacity(0.4),
                        radius: 30
                    )
                    .opacity(wordVisible ? 1 : 0)
                    .scaleEffect(wordVisible ? 1.0 : 0.88)
                    .animation(.easeOut(duration: 0.18), value: wordVisible)
            }

            VStack {
                Spacer()
                Text("tap to continue")
                    .font(.system(size: 7, weight: .light))
                    .tracking(3.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(hasFlashed ? 0.30 : 0))
                    .animation(.easeOut(duration: 1.2), value: hasFlashed)
                    .padding(.bottom, 80)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if hasFlashed { onAdvance() } }
        .onAppear { startFlashing() }
        .onDisappear { timer?.invalidate() }
    }

    private var currentWord: String {
        guard !words.isEmpty, wordIndex >= 0 else { return "" }
        return words[wordIndex % words.count]
    }

    private var isConsonant: Bool {
        let w = currentWord
        guard !w.isEmpty, w.count <= 4 else { return false }
        return w.allSatisfy { !"aeiouAEIOU".contains($0) }
    }

    private func startFlashing() {
        guard !words.isEmpty else { return }
        flashOnce(at: 0)
        let t = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
            Task { @MainActor in
                let next = (wordIndex + 1) % words.count
                flashOnce(at: next)
            }
        }
        timer = t
    }

    private func flashOnce(at idx: Int) {
        wordIndex = idx
        dimmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            wordVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.96) {
            wordVisible = false
            dimmed = false
            hasFlashed = true
        }
    }
}

// MARK: — Step 5 · Reveal (peak word)

struct RevealStepView: View {
    let hue: Double
    let word: String
    let onAdvance: () -> Void

    @State private var arrived = false

    var body: some View {
        ZStack {
            Color(hex: "#020208").opacity(0.88).ignoresSafeArea()

            // Glow aura
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(
                                color: Color(hue: hue / 360, saturation: 0.50, brightness: 0.40).opacity(0.22),
                                location: 0
                            ),
                            .init(color: .clear, location: 0.7),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .opacity(arrived ? 1 : 0)
                .animation(.easeOut(duration: 1.5), value: arrived)

            Text(word)
                .font(.system(size: 84, weight: .light, design: .serif).italic())
                .foregroundStyle(
                    Color(hue: hue / 360, saturation: 0.55, brightness: 0.74)
                        .opacity(0.95)
                )
                .shadow(
                    color: Color(hue: hue / 360, saturation: 0.55, brightness: 0.65).opacity(0.45),
                    radius: 30
                )
                .shadow(
                    color: Color(hue: hue / 360, saturation: 0.50, brightness: 0.55).opacity(0.20),
                    radius: 60
                )
                .opacity(arrived ? 1 : 0)
                .scaleEffect(arrived ? 1 : 0.8)
                .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.1), value: arrived)
        }
        .contentShape(Rectangle())
        .onTapGesture { if arrived { onAdvance() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                arrived = true
            }
        }
    }
}

// MARK: — Step 6 · Fruit (three paragraphs)

struct FruitStepView: View {
    let hue: Double
    let word: String
    let paragraphs: [String]
    let onAdvance: () -> Void

    @State private var visibleLines = 0

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                Text(word.uppercased())
                    .font(.system(size: 9, weight: .light))
                    .tracking(3.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hue: hue / 360, saturation: 0.45, brightness: 0.62)
                            .opacity(0.55)
                    )
                    .padding(.bottom, 10)

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, para in
                    Text(para)
                        .font(.system(size: 15, weight: .light, design: .serif).italic())
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(paraOpacity(idx)))
                        .multilineTextAlignment(.center)
                        .lineSpacing(12)
                        .opacity(visibleLines > idx ? 1 : 0)
                        .offset(y: visibleLines > idx ? 0 : 7)
                        .animation(.easeOut(duration: 1.4), value: visibleLines)
                        .padding(.horizontal, 38)
                }
            }

            VStack {
                Spacer()
                Text("tap to continue")
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(3.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hex: "#F5E2D6").opacity(visibleLines >= paragraphs.count ? 0.30 : 0)
                    )
                    .animation(.easeOut(duration: 2.0), value: visibleLines)
                    .padding(.bottom, 80)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if visibleLines >= paragraphs.count { onAdvance() } }
        .onAppear { startArrival() }
    }

    private func paraOpacity(_ i: Int) -> Double {
        switch i {
        case 0: return 0.82
        case 1: return 0.65
        default: return 0.75
        }
    }

    private func startArrival() {
        let timings: [Double] = [0.6, 2.6, 4.8]
        for (i, t) in timings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                visibleLines = i + 1
            }
        }
    }
}

// MARK: — Step 7 · Lalita (closing line)

struct LalitaStepView: View {
    let line: String
    let onClose: () -> Void

    @State private var phase = 0  // 0=hidden, 1=line, 2=close affordance

    var body: some View {
        ZStack {
            Color(hex: "#020208").opacity(phase >= 2 ? 0.6 : 0).ignoresSafeArea()
                .animation(.easeInOut(duration: 2.0), value: phase)

            VStack(spacing: 18) {
                Text(line)
                    .font(.system(size: 16, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(phase == 1 ? 0.55 : 0))
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 44)
                    .animation(.easeInOut(duration: 2.5), value: phase)

                if phase >= 2 {
                    VStack(spacing: 10) {
                        Text("◉")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.45))
                        Text("close the loop")
                            .font(.system(size: 7.5, weight: .light))
                            .tracking(3.0)
                            .textCase(.uppercase)
                            .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.35))
                    }
                    .transition(.opacity)
                    .padding(.top, 12)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if phase >= 2 { onClose() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                withAnimation { phase = 2 }
            }
        }
    }
}
