import SwiftUI

struct PlayerView: View {
    let track: Track
    @State private var store = PlayerStore.shared
    @State private var trackPlayer = TrackPlaybackService.shared
    @State private var hudVisible: Bool = true
    @State private var hudHideTask: Task<Void, Never>?
    @State private var sessionDuration: TimeInterval = SettingsStore.shared.defaultSessionDuration
    @State private var startTime: Date = Date()

    private let theme = ThemeData.void

    private var elementColor: Color {
        switch track.element {
        case .earth:       return Color(hue: 15/360,  saturation: 0.55, brightness: 0.85)
        case .water:       return Color(hue: 210/360, saturation: 0.50, brightness: 0.90)
        case .fire:        return Color(hue: 25/360,  saturation: 0.65, brightness: 0.95)
        case .air:         return Color(hue: 195/360, saturation: 0.40, brightness: 0.92)
        case .light:       return Color(hue: 50/360,  saturation: 0.50, brightness: 0.95)
        case .crown:       return Color(hue: 280/360, saturation: 0.45, brightness: 0.90)
        case .soul:        return Color(hue: 265/360, saturation: 0.50, brightness: 0.85)
        case .dissolution: return Color(hue: 190/360, saturation: 0.40, brightness: 0.85)
        case .meditate:    return Color(hue: 0,       saturation: 0.0,  brightness: 0.75)
        case .family:      return Color(hue: 330/360, saturation: 0.35, brightness: 0.88)
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            let isInfinite = sessionDuration >= 99_999
            let remaining = isInfinite ? elapsed : max(0, sessionDuration - elapsed)
            // Binaural countdown only auto-closes when no track is playing.
            let expired = !isInfinite && remaining < 0.4 && !trackPlayer.isPlaying

            ZStack {
                // Background: radial gradient from element color (faint) to black
                RadialGradient(
                    colors: [elementColor.opacity(0.12), theme.bg],
                    center: .center,
                    startRadius: 80,
                    endRadius: 600
                )
                .ignoresSafeArea()

                // Visualizer OR loading state (mutually exclusive in this slot)
                if store.isLoadingTrack {
                    loadingView
                } else {
                    VisualizerView(beat: store.currentBeat, color: elementColor)
                        .frame(width: 320, height: 320)
                }

                // Foreground content
                VStack(spacing: 0) {
                    topBar(remaining: remaining)
                        .opacity(hudVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: hudVisible)

                    if !trackPlayer.isPlaying {
                        durationChips
                            .opacity(hudVisible ? 1 : 0)
                            .animation(.easeInOut(duration: 0.4), value: hudVisible)
                            .padding(.top, 4)
                    }

                    Spacer()

                    // Verb (huge)
                    Text(track.verb)
                        .font(.system(size: 64, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(elementColor)
                        .shadow(color: elementColor.opacity(0.5), radius: 20)

                    // Song + artist
                    VStack(spacing: 4) {
                        Text(track.song)
                            .font(.system(size: 18, design: .serif))
                            .foregroundColor(theme.text)
                        Text(track.artist)
                            .font(.system(size: 13))
                            .foregroundColor(theme.muted)
                    }
                    .padding(.top, 12)

                    Spacer()

                    // Seed phrase
                    Text(track.seed)
                        .font(.system(size: 16, design: .serif))
                        .italic()
                        .foregroundColor(theme.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: 340)

                    Spacer()

                    // Track progress (only while music is playing)
                    if trackPlayer.isPlaying {
                        trackProgressView
                            .opacity(hudVisible ? 1 : 0)
                            .animation(.easeInOut(duration: 0.4), value: hudVisible)
                            .padding(.bottom, 16)
                    }

                    // Bottom: track info chips
                    HStack(spacing: 16) {
                        InfoChip(label: "carrier", value: "\(Int(store.currentCarrier)) Hz")
                        InfoChip(label: "beat", value: String(format: "%.1f Hz", store.currentBeat))
                        InfoChip(label: "state", value: track.state.rawValue)
                    }
                    .opacity(hudVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: hudVisible)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                hudVisible.toggle()
                resetHudTimer()
            }
            .onAppear {
                startTime = Date()
                resetHudTimer()
            }
            .onDisappear { hudHideTask?.cancel() }
            .onChange(of: expired) { _, didExpire in
                if didExpire { store.closePlayer() }
            }
            .onChange(of: trackPlayer.hasCompleted) { _, completed in
                if completed { store.closePlayer() }
            }
        }
    }

    @ViewBuilder
    private func topBar(remaining: TimeInterval) -> some View {
        HStack {
            Button(action: { store.minimizePlayer() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(theme.muted)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(trackPlayer.isPlaying ? formatPlayerTime(trackPlayer.elapsed) : formatPlayerTime(remaining))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.muted)
            Spacer()
            Button(action: { store.closePlayer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(theme.muted)
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var durationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "5 min", isSelected: sessionDuration == 300) { sessionDuration = 300 }
                Chip(label: "10 min", isSelected: sessionDuration == 600) { sessionDuration = 600 }
                Chip(label: "20 min", isSelected: sessionDuration == 1200) { sessionDuration = 1200 }
                Chip(label: "30 min", isSelected: sessionDuration == 1800) { sessionDuration = 1800 }
                Chip(label: "∞", isSelected: sessionDuration >= 99_999) { sessionDuration = 999_999 }
            }
            .padding(.horizontal, 20)
        }
    }

    private var trackProgressView: some View {
        VStack(spacing: 6) {
            ProgressView(value: trackPlayer.elapsed, total: max(trackPlayer.duration, 0.1))
                .tint(theme.accent)
            HStack {
                Text(formatPlayerTime(trackPlayer.elapsed))
                Spacer()
                Text(formatPlayerTime(trackPlayer.duration))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(theme.muted)
        }
        .padding(.horizontal, 40)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(theme.accent)
                .scaleEffect(1.2)
            Text("fetching the field...")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
        }
        .frame(width: 320, height: 320)
    }

    private func resetHudTimer() {
        hudHideTask?.cancel()
        hudHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            if !Task.isCancelled {
                await MainActor.run { hudVisible = false }
            }
        }
    }

    private func formatPlayerTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct InfoChip: View {
    let label: String
    let value: String
    private let theme = ThemeData.void

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .foregroundColor(theme.subtle)
                .tracking(1.2)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(theme.muted)
        }
    }
}
