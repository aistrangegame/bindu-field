import SwiftUI

struct LabView: View {
    @State private var store = PlayerStore.shared
    @State private var carrier: Float = 136.0
    @State private var beat: Float = 10.0
    @State private var isPlaying: Bool = false

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
                    Text(stateLabel)
                        .font(.system(size: 11))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(stateColor)
                    Text("carrier \(Int(carrier)) Hz")
                        .font(.system(size: 10))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
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
