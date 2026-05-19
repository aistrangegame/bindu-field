import SwiftUI
import UIKit

struct LabView: View {
    @State private var store = PlayerStore.shared
    @State private var presetStore = PresetStore.shared
    @State private var carrier: Float = 136.0
    @State private var beat: Float = 10.0
    @State private var isPlaying: Bool = false

    // Brainwave state info card expansion (tap the state label).
    @State private var stateInfoExpanded = false

    // Carrier-note popover trigger (tap the dot next to "carrier X Hz").
    @State private var carrierNoteVisible = false

    // Inline "save preset" naming flow.
    @State private var isNamingPreset = false
    @State private var newPresetName = ""
    @FocusState private var presetNameFocused: Bool

    // Long-press-to-delete on user presets.
    @State private var presetPendingDelete: FrequencyPreset? = nil

    @Environment(\.binduTheme) private var theme

    private var stateLabel: String {
        switch beat {
        case 0..<4:     return "delta"
        case 4..<6.5:   return "theta"
        case 6.5..<8.5: return "theta-alpha"
        case 8.5..<14:  return "alpha"
        case 14..<30:   return "beta"
        default:        return "gamma"
        }
    }

    private var stateColor: Color {
        switch beat {
        case 0..<4:     return Color(hue: 0.78, saturation: 0.5, brightness: 0.9)   // violet (delta)
        case 4..<6.5:   return Color(hue: 0.65, saturation: 0.5, brightness: 0.9)   // indigo (theta)
        case 6.5..<8.5: return Color(hue: 0.55, saturation: 0.4, brightness: 0.92)  // cyan (theta-alpha)
        case 8.5..<14:  return Color(hue: 0.40, saturation: 0.5, brightness: 0.9)   // green (alpha)
        case 14..<30:   return Color(hue: 0.12, saturation: 0.6, brightness: 0.95)  // amber (beta)
        default:        return Color(hue: 0.02, saturation: 0.6, brightness: 0.95)  // red (gamma)
        }
    }

    var body: some View {
        ZStack {
            // Subtle background tint from state color
            RadialGradient(
                colors: [stateColor.opacity(isPlaying ? 0.15 : 0.05), theme.bg],
                center: .center,
                startRadius: 80,
                endRadius: 600
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: stateColor)
            .animation(.easeInOut(duration: 0.6), value: isPlaying)

            VStack(spacing: 28) {
                // Title
                VStack(spacing: 8) {
                    Text("Lab")
                        .font(.system(size: 32, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("find your own frequency")
                        .font(.system(size: 14))
                        .foregroundColor(theme.muted)
                }
                .padding(.top, 40)

                Spacer()

                // Big readout
                VStack(spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(String(format: "%.1f", beat))
                            .font(.system(size: 76, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(theme.text)
                        Text("Hz")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(theme.muted)
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stateInfoExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(stateLabel)
                                .font(.system(size: 11))
                                .tracking(3)
                                .textCase(.uppercase)
                                .foregroundColor(stateColor)
                            Image(systemName: stateInfoExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(stateColor.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)

                    if stateInfoExpanded, let info = FrequencyInfo.brainwaveInfo(forLabel: stateLabel) {
                        VStack(spacing: 6) {
                            Text(info.range)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(theme.subtle)
                            Text(info.essence)
                                .font(.system(size: 13, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted)
                                .multilineTextAlignment(.center)
                            Text(info.detail)
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    HStack(spacing: 6) {
                        Text("carrier \(Int(carrier)) Hz")
                            .font(.system(size: 10))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(theme.subtle)
                        if let note = FrequencyInfo.carrierNote(for: carrier) {
                            Button(action: { carrierNoteVisible = true }) {
                                Circle()
                                    .fill(theme.accent.opacity(0.75))
                                    .frame(width: 5, height: 5)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $carrierNoteVisible, attachmentAnchor: .point(.center), arrowEdge: .bottom) {
                                Text(note)
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.text)
                                    .multilineTextAlignment(.center)
                                    .padding(16)
                                    .frame(maxWidth: 240)
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }

                Spacer()

                // Sliders
                VStack(spacing: 24) {
                    SliderControl(
                        label: "carrier",
                        value: $carrier,
                        range: 40...440,
                        format: "%.0f Hz",
                        onChange: { newCarrier in
                            // B7: BinauralEngine.start() guards `if isRunning { return }`,
                            // so re-calling startBinaural mid-play was silently a no-op.
                            // setCarrier directly updates the running engine's glide target.
                            if isPlaying {
                                store.setCarrier(newCarrier)
                            }
                        },
                        onCommit: nil
                    )

                    SliderControl(
                        label: "beat",
                        value: $beat,
                        range: 0.5...30,
                        format: "%.1f Hz",
                        onChange: { newBeat in
                            if isPlaying {
                                store.setBeat(newBeat)
                            }
                        },
                        onCommit: nil
                    )
                }
                .padding(.horizontal, 24)

                // Preset row — system presets + user-saved + inline "+ save".
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetStore.allPresets) { preset in
                            presetChip(preset)
                        }
                        saveChip
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 2)
                }

                Spacer()

                // Play/stop button
                Button(action: togglePlay) {
                    ZStack {
                        Circle()
                            .fill(stateColor.opacity(isPlaying ? 0.25 : 0.10))
                            .frame(width: 96, height: 96)
                        Circle()
                            .stroke(stateColor.opacity(0.8), lineWidth: 1.2)
                            .frame(width: 96, height: 96)
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(theme.text)
                            .offset(x: isPlaying ? 0 : 3)
                    }
                }
                .padding(.bottom, 60)
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
    }

    // MARK: - Preset chips

    @ViewBuilder
    private func presetChip(_ preset: FrequencyPreset) -> some View {
        let fill: Color = preset.isSystem
            ? theme.muted.opacity(0.15)
            : theme.text.opacity(0.08)
        let isActive = abs(carrier - preset.carrierHz) < 0.05
            && abs(beat - preset.beatHz) < 0.05

        Text(preset.name)
            .font(.system(size: 10, design: .serif))
            .italic()
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(isActive ? theme.text : theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(
                        Capsule().stroke(
                            theme.muted.opacity(isActive ? 0.5 : 0.0),
                            lineWidth: 1
                        )
                    )
            )
            .contentShape(Capsule())
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
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.bg)
                        .padding(5)
                        .background(Circle().fill(theme.text))
                }
                .buttonStyle(.plain)
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: cancelNewPreset) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.muted)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(theme.muted.opacity(0.10)))
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isNamingPreset = true
                }
                presetNameFocused = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                    Text("save")
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .tracking(1.5)
                        .textCase(.uppercase)
                }
                .foregroundColor(theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func applyPreset(_ preset: FrequencyPreset) {
        withAnimation(.easeOut(duration: 0.4)) {
            carrier = preset.carrierHz
            beat = preset.beatHz
        }
        if isPlaying {
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
        withAnimation(.easeInOut(duration: 0.2)) {
            isNamingPreset = false
        }
    }

    private func cancelNewPreset() {
        newPresetName = ""
        presetNameFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isNamingPreset = false
        }
    }

    private func togglePlay() {
        if isPlaying {
            store.stopBinaural()
            NowPlayingService.shared.clear()
            isPlaying = false
        } else {
            store.startBinaural(carrier: carrier, beat: beat)
            store.setGain(SettingsStore.shared.gain)
            // G6: Lab is open-ended in spirit, but if the user has set a
            // `defaultSessionDuration` we surface it on the lock screen so
            // the progress bar reflects their intended sit length.
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
}

private struct SliderControl: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    let onChange: ((Float) -> Void)?
    let onCommit: ((Float) -> Void)?

    @Environment(\.binduTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(theme.subtle)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.muted)
            }

            Slider(value: $value, in: range, onEditingChanged: { editing in
                if !editing {
                    onCommit?(value)
                }
            })
            .tint(theme.accent)
            .onChange(of: value) { _, newValue in
                onChange?(newValue)
            }
        }
    }
}
