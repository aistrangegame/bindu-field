import SwiftUI

struct PlayerView: View {
    let track: Track
    @State private var store = PlayerStore.shared
    @State private var trackPlayer = TrackPlaybackService.shared
    @State private var wire = DSPWireService.shared
    @State private var hudVisible: Bool = true
    @State private var hudHideTask: Task<Void, Never>?
    @State private var sessionDuration: TimeInterval = SettingsStore.shared.defaultSessionDuration
    @State private var startTime: Date = Date()

    // 4A: arrival ceremony
    @State private var hasArrived: Bool = false

    // 4D: binaural pill expanded state
    @State private var pillExpanded: Bool = false

    // Step 5: Integration Chamber
    @State private var showingIntegration: Bool = false
    @State private var integrationText: String = ""
    @State private var integrationDismissTask: Task<Void, Never>?

    private let theme = ThemeData.void

    private var elementColor: Color {
        Color.bindu(element: track.element)
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

                    durationChips
                        .opacity(hudVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: hudVisible)
                        .padding(.top, 4)
                        .allowsHitTesting(!trackPlayer.isPlaying)

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

                    // 4C: read-only scrubber (below song/artist, above seed)
                    if trackPlayer.isPlaying {
                        trackProgressView
                            .padding(.top, 18)
                    }

                    // Persistent stop control — always visible, independent of HUD
                    Button(action: { store.closePlayer() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .light))
                            Text("stop")
                                .font(.system(size: 13, design: .serif))
                                .italic()
                        }
                        .foregroundColor(theme.muted)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)

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
            // 4A: arrival ceremony — content breathes in
            .opacity(hasArrived ? 1.0 : 0)
            .scaleEffect(hasArrived ? 1.0 : 0.96)
            // 4D: binaural pill — top-anchored, always visible, outside HUD opacity
            .overlay(alignment: .top) {
                binauralPill
                    .padding(.top, 64)
            }
            // Step 5: Integration Chamber overlay
            .overlay {
                if showingIntegration {
                    integrationChamber
                        .transition(.opacity)
                }
            }
            .onAppear {
                startTime = Date()
                resetHudTimer()
                withAnimation(.easeOut(duration: 0.6)) { hasArrived = true }
            }
            .onDisappear {
                hudHideTask?.cancel()
                integrationDismissTask?.cancel()
            }
            .onChange(of: expired) { _, didExpire in
                if didExpire { store.closePlayer() }
            }
            .onChange(of: trackPlayer.hasCompleted) { _, completed in
                if completed { presentIntegration() }
            }
            // BinauralListener posts this when the AVAudioFile finishes.
            .onReceive(NotificationCenter.default.publisher(for: .binduPlaybackComplete)) { _ in
                presentIntegration()
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

    /// Read-only progress display. Tap-to-seek is intentionally not wired —
    /// seeking music requires repositioning BinauralListener's player node,
    /// which is out of scope for this session.
    private var trackProgressView: some View {
        let elapsed = trackPlayer.elapsed
        let duration = max(trackPlayer.duration, 0.1)
        let progress = min(max(elapsed / duration, 0), 1)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.muted.opacity(0.20))
                        .frame(height: 3)
                    Capsule()
                        .fill(elementColor)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatPlayerTime(elapsed))
                Spacer()
                Text("-\(formatPlayerTime(max(0, duration - elapsed)))")
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

    // MARK: - 4D: Binaural presence pill

    private var binauralPill: some View {
        let on = wire.binauralEnabled
        return VStack(spacing: 0) {
            // Header — always visible, tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { pillExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .strokeBorder(theme.muted.opacity(on ? 0 : 0.5), lineWidth: 1)
                        .background(Circle().fill(on ? theme.accent : Color.clear))
                        .frame(width: 8, height: 8)
                    Text("binaural")
                        .font(.system(size: 11))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundColor(theme.muted)
                    Image(systemName: pillExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(theme.subtle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if pillExpanded {
                VStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { wire.binauralEnabled },
                        set: { wire.binauralEnabled = $0 }
                    )) {
                        Text("BINAURAL")
                            .font(.system(size: 10, weight: .light))
                            .tracking(2)
                            .foregroundColor(theme.subtle)
                    }
                    .tint(theme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("PRESENCE")
                                .font(.system(size: 10, weight: .light))
                                .tracking(2)
                                .foregroundColor(theme.subtle)
                            Spacer()
                            Text(String(format: "%.0f%%", wire.userPresence * 100))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(theme.muted)
                        }
                        Slider(value: Binding(
                            get: { Double(wire.userPresence) },
                            set: { wire.userPresence = Float($0) }
                        ), in: 0.0...1.0)
                        .tint(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: 240)
            }
        }
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(pillExpanded ? 0 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(pillExpanded ? 1 : 0)
        )
        .overlay {
            if pillExpanded {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.muted.opacity(0.18), lineWidth: 1)
            } else {
                Capsule(style: .continuous)
                    .stroke(theme.muted.opacity(0.18), lineWidth: 1)
            }
        }
    }

    // MARK: - Step 5: Integration Chamber

    private var integrationChamber: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("what did you remember?")
                    .font(.system(size: 24, weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("", text: $integrationText, axis: .vertical)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .lineLimit(2...5)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.muted.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)

                HStack(spacing: 12) {
                    Button {
                        dismissIntegration(save: false)
                    } label: {
                        Text("close")
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismissIntegration(save: true)
                    } label: {
                        Text("save note")
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundColor(theme.bg)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(theme.text))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 32)
        }
    }

    private func presentIntegration() {
        guard !showingIntegration else { return }
        showingIntegration = true
        integrationText = ""

        // Auto-dismiss after 30s if the user does nothing.
        integrationDismissTask?.cancel()
        integrationDismissTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    if showingIntegration {
                        dismissIntegration(save: false)
                    }
                }
            }
        }
    }

    private func dismissIntegration(save: Bool) {
        integrationDismissTask?.cancel()
        integrationDismissTask = nil
        if save {
            let trimmed = integrationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                store.pendingNote = trimmed
            }
        }
        showingIntegration = false
        store.closePlayer()
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
