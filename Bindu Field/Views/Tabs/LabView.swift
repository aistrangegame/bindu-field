import SwiftUI
import UIKit

// MARK: - LabView (Bindu Lab v3)
//
// The redesign collapses each frequency from two controls (editable readout
// + far-below slider) into ONE control cluster (`TuningCluster`): hero
// readout, draggable slider, and flanking ± steppers. Marker dots on the
// slider show sacred carriers / brainwave-band boundaries, and only the
// nearest one renders a floating label — the fix for the old label
// collision bug.
//
// The knowledge layer (`MeaningPanel`) is calm at rest: a single italic
// line that synthesizes beat → brainwave state and carrier → sacred
// association, each with inline honesty-tier badges. Tap to expand the
// full per-state and per-carrier detail.
//
// Audio path is unchanged. PlayerStore drives BinauralEngine; the Lab
// claims `.lab` from AudioExclusivityCoordinator on ACTIVATE and listens
// for the `.binduLabStop` eviction notification.

struct LabView: View {
    @State private var store = PlayerStore.shared
    @State private var presetStore = PresetStore.shared

    @State private var carrier: Float = 136.1
    @State private var beat: Float = 7.83
    @State private var isPlaying: Bool = false

    // The "let the field choose" randomize cycles `displayCarrier`/`displayBeat`
    // for visual flicker. The committed values (`carrier`/`beat`) only update
    // at the final spring lock-in so the engine doesn't glide through noise.
    @State private var randomizing = false
    @State private var displayCarrier: Float = 136.1
    @State private var displayBeat: Float = 7.83

    // MeaningPanel expanded state — calm at rest, tap to expand.
    @State private var meaningExpanded = false

    // Preset save flow.
    @State private var isNamingPreset = false
    @State private var newPresetName = ""
    @FocusState private var presetNameFocused: Bool

    // Long-press-to-delete on user presets.
    @State private var presetPendingDelete: FrequencyPreset? = nil

    @Environment(\.binduTheme) private var theme

    // Range + step (taken from the current Lab — `BinauralEngine` clamps
    // carrier internally to 60–500, so 40–440 here means the displayed
    // value can dip below 60; the engine still plays back at 60 in that
    // case. Beat is 0.5–44 to match the prior Lab and gives some headroom
    // beyond the engine's 0.5–40 ceiling).
    private let carrierMin: Float = 40
    private let carrierMax: Float = 440
    private let carrierStep: Float = 0.1
    // ± stepper precision matches the readout precision so a user can
    // reach values like 136.1 (OM) and 2.69 Hz one tap at a time without
    // having to type. The slider drag remains the coarse control.
    private let carrierFineStep: Float = 0.1      // ± stepper moves by 0.1 Hz (matches 1-decimal readout)
    private let beatMin: Float = 0.5
    private let beatMax: Float = 44
    private let beatStep: Float = 0.1
    private let beatFineStep: Float = 0.01        // ± stepper moves by 0.01 Hz (matches 2-decimal readout)

    // MARK: - Derived

    private var shownCarrier: Float { randomizing ? displayCarrier : carrier }
    private var shownBeat: Float { randomizing ? displayBeat : beat }
    private var stateInfo: BrainwaveStateInfo { .forBeat(shownBeat) }
    private var stateColor: Color { stateInfo.color }
    private var stateHue: Double { stateInfo.hue }
    private var sacredHit: SacredCarrier? { SacredCarrier.nearest(shownCarrier, threshold: 1.8) }

    // Slider markers
    private var carrierMarkers: [(hz: Float, name: String)] {
        SacredCarrier.all
            .filter { $0.hz >= carrierMin && $0.hz <= carrierMax }
            .map { ($0.hz, $0.name) }
    }
    private let beatMarkers: [(hz: Float, name: String)] = [
        (4, "δ/θ"), (8, "θ/α"), (13, "α/β"), (30, "β/γ"),
    ]

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            // Dynamic state atmosphere wash.
            RadialGradient(
                colors: [
                    Color(hue: stateHue / 360, saturation: 0.40, brightness: 0.14)
                        .opacity(isPlaying ? 0.22 : 0.10),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: stateHue)
            .animation(.easeInOut(duration: 0.6), value: isPlaying)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .padding(.bottom, 18)

                    waveformStrip
                        .padding(.bottom, 24)

                    TuningCluster(
                        label: "BEAT",
                        value: shownBeat,
                        min: beatMin,
                        max: beatMax,
                        step: beatStep,
                        fineStep: beatFineStep,
                        hue: stateHue,
                        markers: beatMarkers,
                        decimalDigits: 2,
                        onChange: setBeat,
                        disabled: randomizing
                    )
                    .padding(.bottom, 24)

                    TuningCluster(
                        label: "CARRIER",
                        value: shownCarrier,
                        min: carrierMin,
                        max: carrierMax,
                        step: carrierStep,
                        fineStep: carrierFineStep,
                        hue: stateHue,
                        markers: carrierMarkers,
                        decimalDigits: 1,
                        onChange: setCarrier,
                        disabled: randomizing
                    )
                    .padding(.bottom, 22)

                    Rectangle()
                        .fill(theme.border)
                        .frame(height: 1)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)

                    MeaningPanel(
                        beat: shownBeat,
                        carrier: shownCarrier,
                        expanded: $meaningExpanded
                    )
                    .padding(.bottom, 24)

                    presetsBlock
                        .padding(.bottom, 28)

                    actionRow
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
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
        // Audio exclusivity — another source claimed the bus. Stop locally
        // so the tone fades, then sync UI.
        .onReceive(NotificationCenter.default.publisher(for: .binduLabStop)) { _ in
            if isPlaying {
                store.stopBinaural()
                NowPlayingService.shared.clear()
                isPlaying = false
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isPlaying ? stateColor : theme.subtle)
                    .frame(width: 5, height: 5)
                    .shadow(color: isPlaying ? stateColor.opacity(0.6) : .clear, radius: 4)
                Text("frequency lab")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Spacer()
            }
            Text("craft your own permission slip")
                .font(.system(size: 9, weight: .light, design: .monospaced))
                .tracking(1.8)
                .foregroundColor(theme.subtle)
                .padding(.leading, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Waveform

    @ViewBuilder
    private var waveformStrip: some View {
        BinauralWaveformView(
            carrierHz: shownCarrier,
            beatHz: shownBeat,
            isActive: isPlaying,
            stateHue: stateHue
        )
        .frame(height: 96)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    // MARK: - Presets

    @ViewBuilder
    private var presetsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS")
                .font(.system(size: 8.5, weight: .light, design: .monospaced))
                .tracking(2.8)
                .foregroundColor(theme.subtle)
                .padding(.horizontal, 28)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Leading insets (matches design — first chip never clips).
                    Spacer().frame(width: 20)
                    ForEach(presetStore.allPresets) { preset in
                        presetChip(preset)
                    }
                    saveChip
                    // Trailing inset
                    Spacer().frame(width: 20)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func presetChip(_ preset: FrequencyPreset) -> some View {
        let isActive = abs(carrier - preset.carrierHz) < 0.7
            && abs(beat - preset.beatHz) < 0.18
        let fill: Color = isActive
            ? Color(hue: stateHue / 360, saturation: 0.38, brightness: 0.14)
            : theme.surface
        let border: Color = isActive ? stateColor.opacity(0.42) : theme.border

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(preset.name)
                    .font(.system(size: 12.5, design: .serif))
                    .italic()
                    .foregroundColor(isActive ? theme.text : theme.muted)
                if !preset.isSystem {
                    Text("×")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(theme.subtle.opacity(0.6))
                        .onTapGesture { presetPendingDelete = preset }
                }
            }
            Text(chipTag(preset))
                .font(.system(size: 8, weight: .light, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(theme.subtle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
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
            HStack(spacing: 8) {
                TextField("name…", text: $newPresetName)
                    .font(.system(size: 12.5, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .focused($presetNameFocused)
                    .frame(width: 90)
                    .submitLabel(.done)
                    .onSubmit { commitNewPreset() }
                Button(action: commitNewPreset) {
                    Text("save")
                        .font(.system(size: 8, weight: .light, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(stateColor)
                }
                .buttonStyle(.plain)
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.border, lineWidth: 1))
            )
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isNamingPreset = true }
                presetNameFocused = true
            }) {
                Text("+ save")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(theme.subtle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: letTheFieldChoose) {
                Text(randomizing ? "choosing…" : "let the field choose")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(randomizing ? theme.subtle : theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().stroke(theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(randomizing)

            Button(action: togglePlay) {
                Text(isPlaying ? "◼ ACTIVE" : "ACTIVATE")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .tracking(2.2)
                    .foregroundColor(theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(isPlaying ? stateColor : theme.text)
                    )
                    .binduGlow(
                        color: isPlaying ? stateColor : .clear,
                        tight: isPlaying ? 0.22 : 0,
                        wide: isPlaying ? 0.08 : 0
                    )
            }
            .buttonStyle(.plain)
            .layoutPriority(1.2)
        }
        .animation(.easeOut(duration: 0.4), value: isPlaying)
    }

    // MARK: - Actions

    private func setCarrier(_ v: Float) {
        let clamped = max(carrierMin, min(carrierMax, v))
        carrier = clamped
        displayCarrier = clamped
        if isPlaying || store.isPlaying { store.setCarrier(clamped) }
    }

    private func setBeat(_ v: Float) {
        let clamped = max(beatMin, min(beatMax, v))
        beat = clamped
        displayBeat = clamped
        if isPlaying || store.isPlaying { store.setBeat(clamped) }
    }

    private func letTheFieldChoose() {
        guard !randomizing else { return }

        // Weighted brainwave-state target
        let roll = Double.random(in: 0..<1)
        let targetBeat: Float
        switch roll {
        case ..<0.12: targetBeat = Float.random(in: 0.5...4.0)
        case ..<0.45: targetBeat = Float.random(in: 4.0...8.0)
        case ..<0.82: targetBeat = Float.random(in: 8.0...13.0)
        case ..<0.95: targetBeat = Float.random(in: 13.0...30.0)
        default:      targetBeat = Float.random(in: 30.0...40.0)
        }
        // Sacred carrier ±0.5 jitter
        let pool = SacredCarrier.all.filter { $0.hz >= carrierMin && $0.hz <= carrierMax }
        let base = pool.randomElement()?.hz ?? 136.1
        let targetCarrier = max(carrierMin, min(carrierMax, base + Float.random(in: -0.5...0.5)))

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        randomizing = true
        let steps = 10
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                if i < steps {
                    displayCarrier = Float.random(in: carrierMin...carrierMax)
                    displayBeat = Float.random(in: beatMin...min(beatMax, 40))
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
                        carrier = round(targetCarrier * 10) / 10
                        beat = round(targetBeat * 10) / 10
                        displayCarrier = carrier
                        displayBeat = beat
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isPlaying || store.isPlaying {
                        store.setCarrier(carrier)
                        store.setBeat(beat)
                    }
                    randomizing = false
                }
            }
        }
    }

    private func togglePlay() {
        if isPlaying {
            store.stopBinaural()
            NowPlayingService.shared.clear()
            isPlaying = false
            AudioExclusivityCoordinator.shared.release(.lab)
        } else {
            AudioExclusivityCoordinator.shared.request(.lab)
            store.startBinaural(carrier: carrier, beat: beat)
            store.setGain(SettingsStore.shared.gain)
            let duration = SettingsStore.shared.defaultSessionDuration
            NowPlayingService.shared.updateForLab(
                stateLabel: stateInfo.key,
                carrier: carrier,
                beat: beat,
                duration: duration > 0 ? duration : nil
            )
            isPlaying = true
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
            case "Creative":   return "174 Hz · open"
            case "Presence":   return "432 · aware"
            default: break
            }
        }
        return String(format: "%.1f Hz · %@", preset.beatHz, BrainwaveStateInfo.forBeat(preset.beatHz).key)
    }
}

// MARK: - TuningCluster
//
// Per-frequency block: label + hero readout (tap to type), draggable
// slider, flanking ± steppers. Markers on the track; only the nearest
// renders a floating label so labels never collide.

private struct TuningCluster: View {
    let label: String
    let value: Float
    let min: Float
    let max: Float
    let step: Float
    let fineStep: Float
    let hue: Double
    let markers: [(hz: Float, name: String)]
    let decimalDigits: Int
    let onChange: (Float) -> Void
    var disabled: Bool = false

    @State private var editing = false
    @State private var rawInput = ""
    @FocusState private var fieldFocused: Bool

    @Environment(\.binduTheme) private var theme

    private var accent: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.68)
    }

    private var pct: CGFloat {
        CGFloat((value - min) / Swift.max(0.0001, max - min))
            .clamped(0, 1)
    }

    private var nearest: (hz: Float, name: String)? {
        let candidates = markers.filter { abs($0.hz - value) <= 2.8 }
        return candidates.min { abs($0.hz - value) < abs($1.hz - value) }
    }

    private var formatString: String {
        "%.\(decimalDigits)f"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label + hero readout
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.system(size: 8.5, weight: .light, design: .monospaced))
                    .tracking(2.8)
                    .foregroundColor(theme.subtle)
                Spacer()
                hero
            }
            // Slider + steppers
            HStack(spacing: 10) {
                stepperButton(symbol: "−") {
                    onChange(Swift.max(min, value - fineStep))
                }
                trackBody
                stepperButton(symbol: "+") {
                    onChange(Swift.min(max, value + fineStep))
                }
            }
            .disabled(disabled)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Hero readout (tap to type)

    @ViewBuilder
    private var hero: some View {
        if editing {
            TextField("", text: $rawInput)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .font(.system(size: 40, weight: .light, design: .monospaced))
                .foregroundColor(accent)
                .frame(width: 160, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
                .onSubmit { commit() }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { commit() }
                            .foregroundColor(accent)
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(accent).frame(height: 1).offset(y: 2)
                }
        } else {
            Button(action: beginEdit) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(String(format: formatString, value))
                        .font(.system(size: 40, weight: .light, design: .monospaced))
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.30), radius: 12)
                    Text("Hz")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(0.9)
                        .foregroundColor(theme.muted)
                }
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
    }

    private func beginEdit() {
        rawInput = String(format: formatString, value)
        editing = true
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commit() {
        defer {
            editing = false
            fieldFocused = false
        }
        let cleaned = rawInput
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let v = Float(cleaned) else { return }
        onChange(Swift.max(min, Swift.min(max, v)))
    }

    // MARK: - Slider track

    @ViewBuilder
    private var trackBody: some View {
        GeometryReader { geo in
            ZStack {
                // Hairline track
                Rectangle()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 1)
                // Filled portion
                Rectangle()
                    .fill(accent.opacity(0.50))
                    .frame(width: geo.size.width * pct, height: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Marker dots + nearest floating label
                ForEach(markers, id: \.hz) { m in
                    let mPct = CGFloat((m.hz - min) / Swift.max(0.0001, max - min))
                    if mPct >= 0 && mPct <= 1 {
                        let isNear = nearest?.hz == m.hz
                        ZStack {
                            Circle()
                                .fill(isNear ? accent : Color.white.opacity(0.22))
                                .frame(width: isNear ? 5 : 3, height: isNear ? 5 : 3)
                                .shadow(color: isNear ? accent.opacity(0.5) : .clear, radius: isNear ? 5 : 0)
                            if isNear {
                                Text(m.name)
                                    .font(.system(size: 8, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundColor(accent)
                                    .fixedSize()
                                    .offset(y: -16)
                            }
                        }
                        .position(x: geo.size.width * mPct, y: 22)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.3), value: isNear)
                    }
                }

                // Thumb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: hue / 360, saturation: 0.72, brightness: 0.92),
                                Color(hue: hue / 360, saturation: 0.58, brightness: 0.64),
                            ],
                            center: .init(x: 0.34, y: 0.28),
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    .frame(width: 20, height: 20)
                    .shadow(color: accent.opacity(0.6), radius: 8)
                    .position(x: Swift.max(10, Swift.min(geo.size.width - 10, geo.size.width * pct)), y: 22)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let t = (g.location.x / geo.size.width).clamped(0, 1)
                        let raw = min + Float(t) * (max - min)
                        let snapped = (raw / step).rounded() * step
                        onChange(Swift.max(min, Swift.min(max, snapped)))
                    }
            )
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(theme.muted)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .stroke(theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MeaningPanel
//
// At rest: breathing dot + one italic line (state · essence · sacred). Tap
// to expand into the full state detail + carrier detail + tier legend.
// Honesty tiers ride inline on the resting line as compact letter badges.

private struct MeaningPanel: View {
    let beat: Float
    let carrier: Float
    @Binding var expanded: Bool

    @Environment(\.binduTheme) private var theme

    private var state: BrainwaveStateInfo { .forBeat(beat) }
    private var sacred: SacredCarrier? { SacredCarrier.nearest(carrier, threshold: 1.8) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.28)) { expanded.toggle() }
            }) {
                HStack(alignment: .center, spacing: 10) {
                    // Breathing dot at state color
                    Circle()
                        .fill(state.color)
                        .frame(width: 6, height: 6)
                        .shadow(color: state.color.opacity(0.55), radius: 4)
                        .modifier(BreathDot())
                    // Summary line
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(state.label.lowercased()) · \(state.essence)")
                            .font(.system(size: 12.5, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                        ForEach(state.tiers, id: \.self) { tier in
                            HonestyBadge(tier: tier)
                        }
                        if let s = sacred {
                            Text("·")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(theme.subtle.opacity(0.4))
                            Text(s.name)
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(1.2)
                                .foregroundColor(theme.subtle)
                            ForEach(s.tiers, id: \.self) { tier in
                                HonestyBadge(tier: tier)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.subtle.opacity(0.45))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                expandedContent
                    .padding(.leading, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(state.color.opacity(0.20))
                            .frame(width: 1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Beat · state
            VStack(alignment: .leading, spacing: 8) {
                Text("BEAT · \(state.range)")
                    .font(.system(size: 7.5, weight: .light, design: .monospaced))
                    .tracking(2.4)
                    .foregroundColor(theme.subtle)
                Text(state.detail)
                    .font(.system(size: 13.5, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(state.tiers, id: \.self) { tier in
                        HStack(alignment: .top, spacing: 7) {
                            HonestyBadge(tier: tier, full: true)
                            if let note = state.tierNotes[tier] {
                                Text(note)
                                    .font(.system(size: 10.5, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.subtle.opacity(0.7))
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            // Carrier · sacred
            if let s = sacred {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .padding(.bottom, 14)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CARRIER · \(s.name) · \(s.note)")
                        .font(.system(size: 7.5, weight: .light, design: .monospaced))
                        .tracking(2.4)
                        .foregroundColor(theme.subtle)
                    Text(s.essence)
                        .font(.system(size: 13.5, design: .serif))
                        .italic()
                        .foregroundColor(theme.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(s.detail)
                        .font(.system(size: 11.5, design: .serif))
                        .italic()
                        .foregroundColor(theme.subtle.opacity(0.65))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(s.tiers, id: \.self) { tier in
                            HonestyBadge(tier: tier, full: true)
                        }
                    }
                }
                .padding(.bottom, 14)
            }

            // Tier legend
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(HonestyTier.allCases, id: \.self) { tier in
                    HStack(alignment: .top, spacing: 8) {
                        HonestyBadge(tier: tier)
                        Text(tier.oneLineDescription)
                            .font(.system(size: 10, design: .serif))
                            .italic()
                            .foregroundColor(theme.subtle.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Breathing dot modifier

private struct BreathDot: ViewModifier {
    @State private var brighter = false
    func body(content: Content) -> some View {
        content
            .opacity(brighter ? 1.0 : 0.65)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    brighter = true
                }
            }
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, self))
    }
}
