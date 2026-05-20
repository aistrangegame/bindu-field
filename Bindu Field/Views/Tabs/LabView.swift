import SwiftUI
import UIKit

struct LabView: View {
    @State private var store = PlayerStore.shared
    @State private var presetStore = PresetStore.shared
    @State private var carrier: Float = 136.1
    @State private var beat: Float = 7.83
    @State private var isPlaying: Bool = false

    // Brainwave state info card expansion (tap the state row).
    @State private var stateInfoExpanded = false

    // Inline "save preset" naming flow.
    @State private var isNamingPreset = false
    @State private var newPresetName = ""
    @FocusState private var presetNameFocused: Bool

    // Long-press-to-delete on user presets.
    @State private var presetPendingDelete: FrequencyPreset? = nil

    // 1B — direct number editing on carrier + beat readouts.
    @State private var editingCarrier = false
    @State private var editingBeat = false
    @State private var carrierInput = ""
    @State private var beatInput = ""
    @FocusState private var carrierFocused: Bool
    @FocusState private var beatFocused: Bool

    // 1D — "let the field choose" randomize cycling state. While randomizing
    // the displayed values flicker each step but the model `carrier`/`beat`
    // only commits at the final spring lock-in.
    @State private var randomizing = false
    @State private var displayBeat: Float = 7.83
    @State private var displayCarrier: Float = 136.1

    @Environment(\.binduTheme) private var theme

    // MARK: - State derivation (design palette)
    //
    // Adopting the design's 5-band scheme (delta/theta/alpha/beta/gamma)
    // with clean 4/8/13/30 Hz boundaries — and the design's hue palette so
    // the Lab's color shifts the way the spec shows.

    private var stateLabel: String { Self.label(forBeat: shownBeat) }
    private var stateHue: Double { Self.hue(forLabel: stateLabel) }
    private var stateColor: Color {
        Color(hue: stateHue / 360, saturation: 0.58, brightness: 0.68)
    }
    private var stateEssence: String { Self.essence(forLabel: stateLabel) }
    private var stateDetail: String { Self.detail(forLabel: stateLabel) }
    private var stateRange: String { Self.range(forLabel: stateLabel) }

    private var shownBeat: Float { randomizing ? displayBeat : beat }
    private var shownCarrier: Float { randomizing ? displayCarrier : carrier }

    private var sacredHit: SacredFreq? { SacredFreq.near(shownCarrier, threshold: 1.2) }

    var body: some View {
        ZStack {
            // Background atmosphere — dynamic by state.
            theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [
                    stateColor.opacity(isPlaying ? 0.18 : 0.08),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.30),
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: stateColor)
            .animation(.easeInOut(duration: 0.8), value: isPlaying)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 16)

                waveformStrip
                    .padding(.bottom, 14)

                centralReadout
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)

                stateCard
                    .padding(.bottom, 10)

                sliders
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)

                sacredMap
                    .padding(.bottom, 14)

                presetsBlock
                    .padding(.bottom, 14)

                actionRow
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .alert(
            "Delete preset?",
            isPresented: Binding(
                get: { presetPendingDelete != nil },
                set: { if !$0 { presetPendingDelete = nil } }
            ),
            presenting: presetPendingDelete
        ) { preset in
            Button("Delete", role: .destructive) {
                presetStore.delete(preset)
                presetPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                presetPendingDelete = nil
            }
        } message: { preset in
            Text(preset.name)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    if editingCarrier { commitCarrierEdit() }
                    if editingBeat { commitBeatEdit() }
                    carrierFocused = false
                    beatFocused = false
                    presetNameFocused = false
                }
                .foregroundColor(theme.accent)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isPlaying ? stateColor : theme.subtle)
                    .frame(width: 6, height: 6)
                    .shadow(color: isPlaying ? stateColor.opacity(0.55) : .clear, radius: 4)
                    .opacity(isPlaying ? breathing : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: isPlaying)
                Text("frequency lab")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Spacer()
            }
            Text("craft your own permission slip")
                .font(.system(size: 10, weight: .light))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundColor(theme.subtle)
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Simple breathing modulator for the active dot — 2.4s cycle.
    private var breathing: Double {
        let t = Date().timeIntervalSinceReferenceDate
        return 0.6 + (sin(t * .pi / 1.2) * 0.5 + 0.5) * 0.4
    }

    // MARK: - Waveform (1A)

    @ViewBuilder
    private var waveformStrip: some View {
        BinauralWaveformView(
            carrierHz: shownCarrier,
            beatHz: shownBeat,
            isActive: isPlaying,
            stateHue: stateHue
        )
        .frame(height: 120)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    // MARK: - Central readout

    @ViewBuilder
    private var centralReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Carrier row: label · editable Hz · optional sacred badge (1E)
            HStack(alignment: .center, spacing: 12) {
                Text("CARRIER")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundColor(theme.subtle)

                carrierEditable

                if let hit = sacredHit {
                    sacredBadge(hit)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer(minLength: 0)
            }

            // Big beat readout — 76pt editable, with Hz suffix
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                beatEditable
                Text("Hz")
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .foregroundColor(stateColor.opacity(0.6))
                    .padding(.bottom, 6)
                Spacer(minLength: 0)
            }
            .opacity(randomizing ? 0.85 : 1.0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: sacredHit?.hz)
    }

    @ViewBuilder
    private var carrierEditable: some View {
        if editingCarrier {
            TextField("", text: $carrierInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundColor(stateColor)
                .focused($carrierFocused)
                .frame(width: 84)
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
                .onSubmit { commitCarrierEdit() }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(stateColor).frame(height: 1).offset(y: 2)
                }
        } else {
            Button(action: beginCarrierEdit) {
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", shownCarrier))
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundColor(stateColor)
                    Text("Hz")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(stateColor.opacity(0.7))
                }
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(randomizing)
        }
    }

    @ViewBuilder
    private var beatEditable: some View {
        if editingBeat {
            TextField("", text: $beatInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 76, weight: .ultraLight, design: .monospaced))
                .foregroundColor(stateColor)
                .focused($beatFocused)
                .frame(width: 220)
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
                .onSubmit { commitBeatEdit() }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(stateColor).frame(height: 1).offset(y: 2)
                }
        } else {
            Button(action: beginBeatEdit) {
                Text(String(format: "%.1f", shownBeat))
                    .font(.system(size: 76, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(stateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1).offset(y: 0)
                    }
            }
            .buttonStyle(.plain)
            .disabled(randomizing)
        }
    }

    // MARK: - State card

    @ViewBuilder
    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { stateInfoExpanded.toggle() }
            }) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: stateColor.opacity(0.55), radius: 4)
                    Text(stateLabel.uppercased())
                        .font(.system(size: 9, weight: .light))
                        .tracking(2.2)
                        .foregroundColor(stateColor)
                    Text(stateEssence)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundColor(theme.subtle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.subtle.opacity(0.7))
                        .rotationEffect(.degrees(stateInfoExpanded ? 180 : 0))
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if stateInfoExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(stateDetail)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundColor(theme.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(stateRange) · brainwave band")
                        .font(.system(size: 9, weight: .light))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle.opacity(0.7))
                }
                .padding(.leading, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(stateColor.opacity(0.25))
                        .frame(width: 1)
                        .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Sliders

    @ViewBuilder
    private var sliders: some View {
        VStack(spacing: 14) {
            customSlider(
                label: "CARRIER",
                value: shownCarrier,
                range: 40...440,
                step: 0.1,
                onChange: { v in
                    carrier = v
                    displayCarrier = v
                    if isPlaying || store.isPlaying { store.setCarrier(v) }
                }
            )
            customSlider(
                label: "BEAT",
                value: shownBeat,
                range: 0.5...44,
                step: 0.1,
                onChange: { v in
                    beat = v
                    displayBeat = v
                    if isPlaying || store.isPlaying { store.setBeat(v) }
                }
            )
        }
    }

    @ViewBuilder
    private func customSlider(
        label: String,
        value: Float,
        range: ClosedRange<Float>,
        step: Float,
        onChange: @escaping (Float) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .tracking(2.0)
                .foregroundColor(theme.subtle)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                let pct = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                ZStack(alignment: .leading) {
                    // Hairline track
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                    // Filled portion
                    Capsule()
                        .fill(stateColor)
                        .frame(width: max(0, pct * geo.size.width), height: 1)
                        .shadow(color: stateColor.opacity(0.4), radius: 3)
                    // Thumb
                    Circle()
                        .fill(stateColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: stateColor.opacity(0.5), radius: 6)
                        .offset(x: pct * geo.size.width - 6)
                        .allowsHitTesting(false)
                    // Hidden Slider for gesture
                    Slider(
                        value: Binding(
                            get: { value },
                            set: { onChange($0) }
                        ),
                        in: range,
                        step: step
                    )
                    .opacity(0.01)  // invisible but receives touches
                    .frame(height: 22)
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            .disabled(randomizing)

            Text(String(format: "%.1f Hz", value))
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(stateColor.opacity(0.85))
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: - Sacred frequency map (1C)

    @ViewBuilder
    private var sacredMap: some View {
        GeometryReader { geo in
            let W = geo.size.width - 56  // 28pt padding each side
            let minHz: Float = 40, maxHz: Float = 440
            ZStack(alignment: .topLeading) {
                // Hairline track
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: W, height: 1)
                    .offset(x: 28, y: 11)

                // Sacred dots + labels
                ForEach(SacredFreq.all, id: \.hz) { entry in
                    let pct = CGFloat((entry.hz - minHz) / (maxHz - minHz))
                    let x = 28 + pct * W
                    let isHit = sacredHit?.hz == entry.hz
                    VStack(spacing: 3) {
                        Circle()
                            .fill(isHit ? stateColor : Color.white.opacity(0.22))
                            .frame(width: isHit ? 6 : 3, height: isHit ? 6 : 3)
                            .shadow(color: isHit ? stateColor.opacity(0.55) : .clear, radius: 5)
                        Text(entry.name)
                            .font(.system(size: 7, weight: .light, design: .monospaced))
                            .tracking(0.4)
                            .foregroundColor(isHit ? stateColor : theme.subtle.opacity(0.5))
                    }
                    .position(x: x, y: 14)
                    .animation(.easeInOut(duration: 0.4), value: isHit)
                }

                // Current carrier cursor
                let cPct = CGFloat((shownCarrier - minHz) / (maxHz - minHz))
                let cX = 28 + max(0, min(1, cPct)) * W
                Circle()
                    .fill(stateColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: stateColor.opacity(0.55), radius: 6)
                    .position(x: cX, y: 11)
                    .animation(.easeOut(duration: 0.18), value: shownCarrier)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Presets

    @ViewBuilder
    private var presetsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS")
                .font(.system(size: 9, weight: .light))
                .tracking(2.0)
                .foregroundColor(theme.subtle.opacity(0.55))
                .padding(.horizontal, 28)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetStore.allPresets) { preset in
                        presetChip(preset)
                    }
                    saveChip
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func presetChip(_ preset: FrequencyPreset) -> some View {
        let isActive = abs(carrier - preset.carrierHz) < 0.5
            && abs(beat - preset.beatHz) < 0.2
        let fill: Color = isActive
            ? Color(hue: stateHue / 360, saturation: 0.38, brightness: 0.14)
            : theme.surface
        let border: Color = isActive ? stateColor.opacity(0.33) : theme.border

        VStack(alignment: .leading, spacing: 1) {
            Text(preset.name)
                .font(.system(size: 10, weight: .light))
                .tracking(0.8)
                .foregroundColor(isActive ? stateColor : theme.muted)
            Text(chipTag(preset))
                .font(.system(size: 9, design: .serif))
                .italic()
                .foregroundColor(theme.subtle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { applyPreset(preset) }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard !preset.isSystem else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            presetPendingDelete = preset
        }
    }

    @ViewBuilder
    private var saveChip: some View {
        if isNamingPreset {
            HStack(spacing: 6) {
                TextField("name", text: $newPresetName)
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .focused($presetNameFocused)
                    .frame(width: 84)
                    .submitLabel(.done)
                    .onSubmit { commitNewPreset() }
                Button(action: commitNewPreset) {
                    Text("save")
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(stateColor)
                }
                .buttonStyle(.plain)
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.border, lineWidth: 1))
            )
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isNamingPreset = true }
                presetNameFocused = true
            }) {
                Text("+ save")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(theme.subtle)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action row (randomize + activate)

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 12) {
            // Randomize (1D)
            Button(action: letTheFieldChoose) {
                Text(randomizing ? "choosing…" : "let the field choose")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(randomizing ? theme.subtle : theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(randomizing)

            // Activate (preserves existing togglePlay)
            Button(action: togglePlay) {
                Text(isPlaying ? "ACTIVE  ·  stop" : "ACTIVATE")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(1.8)
                    .foregroundColor(theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(isPlaying ? stateColor : theme.text)
                    )
                    .shadow(
                        color: isPlaying ? stateColor.opacity(0.22) : .clear,
                        radius: 28
                    )
            }
            .buttonStyle(.plain)
            .layoutPriority(1.2)
        }
        .animation(.easeOut(duration: 0.4), value: isPlaying)
    }

    // MARK: - Sacred badge (1E)

    @ViewBuilder
    private func sacredBadge(_ hit: SacredFreq) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 5, height: 5)
                .shadow(color: stateColor.opacity(0.55), radius: 4)
            Text(hit.name)
                .font(.system(size: 8, weight: .regular))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(stateColor)
            Text(hit.note)
                .font(.system(size: 9, design: .serif))
                .italic()
                .foregroundColor(theme.subtle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color(hue: stateHue / 360, saturation: 0.38, brightness: 0.12))
                .overlay(Capsule().stroke(stateColor.opacity(0.27), lineWidth: 1))
        )
    }

    // MARK: - Direct edit helpers (1B)

    private func beginCarrierEdit() {
        guard !randomizing else { return }
        carrierInput = String(format: "%.1f", carrier)
        editingCarrier = true
        DispatchQueue.main.async { carrierFocused = true }
    }

    private func commitCarrierEdit() {
        defer {
            editingCarrier = false
            carrierFocused = false
        }
        let cleaned = carrierInput
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let v = Float(cleaned) else { return }
        let clamped = min(max(v, 40), 440)
        carrier = clamped
        displayCarrier = clamped
        if isPlaying || store.isPlaying { store.setCarrier(clamped) }
    }

    private func beginBeatEdit() {
        guard !randomizing else { return }
        beatInput = String(format: "%.1f", beat)
        editingBeat = true
        DispatchQueue.main.async { beatFocused = true }
    }

    private func commitBeatEdit() {
        defer {
            editingBeat = false
            beatFocused = false
        }
        let cleaned = beatInput
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let v = Float(cleaned) else { return }
        let clamped = min(max(v, 0.5), 44)
        beat = clamped
        displayBeat = clamped
        if isPlaying || store.isPlaying { store.setBeat(clamped) }
    }

    // MARK: - Randomize (1D)
    //
    // Weighted-state distribution + sacred carrier ±0.5 jitter. The cycling
    // visual is 10 quick random flickers, then a spring lock to the final
    // values. Live engine glide kicks in only at lock.

    private func letTheFieldChoose() {
        guard !randomizing else { return }

        // Weighted brainwave-state target
        let roll = Double.random(in: 0..<1)
        let targetBeat: Float
        switch roll {
        case ..<0.12: targetBeat = Float.random(in: 0.5...4.0)    // delta 12%
        case ..<0.45: targetBeat = Float.random(in: 4.0...8.0)    // theta 33%
        case ..<0.82: targetBeat = Float.random(in: 8.0...13.0)   // alpha 37%
        case ..<0.95: targetBeat = Float.random(in: 13.0...30.0)  // beta 13%
        default:      targetBeat = Float.random(in: 30.0...40.0)  // gamma 5%
        }

        // Sacred carrier ±0.5
        let sacredCarriers: [Float] = SacredFreq.all.map(\.hz)
        let base = sacredCarriers.randomElement() ?? 136.1
        let targetCarrier = max(40, min(440, base + Float.random(in: -0.5...0.5)))

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        randomizing = true
        let steps = 10
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                if i < steps {
                    displayCarrier = Float.random(in: 40...440)
                    displayBeat = Float.random(in: 0.5...40)
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
                        carrier = targetCarrier
                        beat = targetBeat
                        displayCarrier = targetCarrier
                        displayBeat = targetBeat
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isPlaying || store.isPlaying {
                        store.setCarrier(targetCarrier)
                        store.setBeat(targetBeat)
                    }
                    randomizing = false
                }
            }
        }
    }

    // MARK: - Presets

    private func applyPreset(_ preset: FrequencyPreset) {
        withAnimation(.easeOut(duration: 0.4)) {
            carrier = preset.carrierHz
            beat = preset.beatHz
            displayCarrier = preset.carrierHz
            displayBeat = preset.beatHz
        }
        if isPlaying || store.isPlaying {
            store.setCarrier(preset.carrierHz)
            store.setBeat(preset.beatHz)
        }
    }

    private func commitNewPreset() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presetStore.save(name: trimmed, carrierHz: carrier, beatHz: beat)
        newPresetName = ""
        presetNameFocused = false
        withAnimation(.easeInOut(duration: 0.2)) { isNamingPreset = false }
    }

    private func chipTag(_ preset: FrequencyPreset) -> String {
        if preset.isSystem {
            switch preset.name {
            case "Earth Tone": return "OM · Schumann"
            case "Deep Delta": return "root descent"
            case "Theta Gate": return "dream portal"
            case "Creative":   return "174 Hz mind"
            case "Presence":   return "432 · open"
            default: break
            }
        }
        let label = Self.label(forBeat: preset.beatHz)
        return String(format: "%.1f Hz · %@", preset.beatHz, label)
    }

    // MARK: - Play

    private func togglePlay() {
        if isPlaying {
            store.stopBinaural()
            NowPlayingService.shared.clear()
            isPlaying = false
        } else {
            store.startBinaural(carrier: carrier, beat: beat)
            store.setGain(SettingsStore.shared.gain)
            let duration = SettingsStore.shared.defaultSessionDuration
            NowPlayingService.shared.updateForLab(
                stateLabel: stateLabel,
                carrier: carrier,
                beat: beat,
                duration: duration > 0 ? duration : nil
            )
            isPlaying = true
        }
    }

    // MARK: - State data (design palette)

    fileprivate static func label(forBeat hz: Float) -> String {
        switch hz {
        case ..<4:  return "delta"
        case ..<8:  return "theta"
        case ..<13: return "alpha"
        case ..<30: return "beta"
        default:    return "gamma"
        }
    }

    fileprivate static func hue(forLabel label: String) -> Double {
        switch label {
        case "delta": return 15
        case "theta": return 260
        case "alpha": return 210
        case "beta":  return 165
        case "gamma": return 50
        default:      return 210
        }
    }

    fileprivate static func essence(forLabel label: String) -> String {
        switch label {
        case "delta": return "deep root · healing · integration"
        case "theta": return "dream · creation · hypnosis"
        case "alpha": return "open · aware · present"
        case "beta":  return "focus · processing · action"
        case "gamma": return "peak insight · binding · clarity"
        default:      return ""
        }
    }

    fileprivate static func detail(forLabel label: String) -> String {
        switch label {
        case "delta":
            return "The deepest ground state. The nervous system releases. The body heals. The field reorganizes below your awareness."
        case "theta":
            return "The door between conscious and unconscious thins. Images arrive without effort. Creativity flows from a place that doesn't know it's creating."
        case "alpha":
            return "Relaxed wakefulness. The witness is active but not grasping. You are here, and here is enough. The nervous system settles into its natural frequency."
        case "beta":
            return "Active cognition. The analytical mind is engaged. Useful for intentional creation and problem-solving. The field thinks through you."
        case "gamma":
            return "The state of peak cognitive binding. Everything connects. Insights arrive whole. Used in advanced practice to sustain heightened awareness."
        default:
            return ""
        }
    }

    fileprivate static func range(forLabel label: String) -> String {
        switch label {
        case "delta": return "0.5–4 Hz"
        case "theta": return "4–8 Hz"
        case "alpha": return "8–13 Hz"
        case "beta":  return "13–30 Hz"
        case "gamma": return "30+ Hz"
        default:      return ""
        }
    }
}

// MARK: - Sacred frequency reference (1C / 1E)
//
// Lab-local reference data. The eight values in FrequencyInfo.carrierNote
// remain the authoritative catalogue for `popoverNote` style usage; this
// table is a richer surface for the inline badge + map strip.

fileprivate struct SacredFreq: Hashable {
    let hz: Float
    let name: String
    let note: String        // musical note name
    let essence: String

    static let all: [SacredFreq] = [
        SacredFreq(hz: 136.1, name: "OM",  note: "C#3", essence: "the cosmic sound · Earth year frequency"),
        SacredFreq(hz: 174.0, name: "174", note: "F3",  essence: "foundation frequency · Solfeggio root"),
        SacredFreq(hz: 285.0, name: "285", note: "D4",  essence: "cellular resonance · field coherence"),
        SacredFreq(hz: 396.0, name: "UT",  note: "G4",  essence: "liberation from fear · root clearing"),
        SacredFreq(hz: 417.0, name: "RE",  note: "G#4", essence: "facilitating change · undoing situations"),
        SacredFreq(hz: 432.0, name: "432", note: "A4♭", essence: "natural resonance · harmonic with nature"),
        SacredFreq(hz: 440.0, name: "440", note: "A4",  essence: "standard concert pitch"),
    ]

    static func near(_ hz: Float, threshold: Float = 1.2) -> SacredFreq? {
        all.first { abs($0.hz - hz) <= threshold }
    }
}
