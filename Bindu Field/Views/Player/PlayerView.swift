import SwiftUI

struct PlayerView: View {
    let track: Track
    @State private var store = PlayerStore.shared
    @State private var trackPlayer = TrackPlaybackService.shared
    @State private var wire = DSPWireService.shared
    @State private var hudVisible: Bool = true
    @State private var hudHideTask: Task<Void, Never>?
    @State private var startTime: Date = Date()

    // 4A: arrival ceremony
    @State private var hasArrived: Bool = false

    // 4D: binaural pill expanded state
    @State private var pillExpanded: Bool = false

    // Step 5: Integration Chamber
    @State private var showingIntegration: Bool = false
    @State private var integrationText: String = ""
    @State private var integrationDismissTask: Task<Void, Never>?

    @Environment(\.binduTheme) private var theme

    private var elementColor: Color {
        Color.bindu(element: track.element)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
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
                    topBar
                        .opacity(hudVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: hudVisible)

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
            .onChange(of: trackPlayer.hasCompleted) { _, completed in
                if completed { presentIntegration() }
            }
            // BinauralListener posts this when the AVAudioFile finishes.
            .onReceive(NotificationCenter.default.publisher(for: .binduPlaybackComplete)) { _ in
                presentIntegration()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { store.minimizePlayer() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(theme.muted)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(trackPlayer.elapsed.asPlaybackTime)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.muted)
                .opacity(trackPlayer.isPlaying ? 1 : 0)
            Spacer()
            Button(action: { store.closePlayer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(theme.muted)
                    .frame(width: 44, height: 44)
            }
        }
    }

    /// Read-only progress display. Tap-to-seek is intentionally not wired —
    /// seeking music requires repositioning BinauralListener's player node,
    /// which is out of scope. G18: the bar is intentionally slim (2 pt) and
    /// captioned "flowing" in serif italic so users don't mistake it for an
    /// interactive scrubber.
    private var trackProgressView: some View {
        let elapsed = trackPlayer.elapsed
        let duration = max(trackPlayer.duration, 0.1)
        let progress = min(max(elapsed / duration, 0), 1)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.muted.opacity(0.20))
                        .frame(height: 2)
                    Capsule()
                        .fill(elementColor)
                        .frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)

            HStack {
                Text(elapsed.asPlaybackTime)
                Spacer()
                Text("flowing")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle)
                Spacer()
                Text("-\(max(0.0, duration - elapsed).asPlaybackTime)")
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

                    // G20: surface the derived-carrier event in text so
                    // users not watching the visualizer still know the
                    // engine has locked onto the song's fundamental.
                    if wire.carrierLocked {
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                                .font(.system(size: 9))
                            Text("carrier · derived")
                                .font(.system(size: 10, design: .serif))
                                .italic()
                        }
                        .foregroundColor(theme.accent)
                        .transition(.opacity)
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
        // Only present from a still-open player. If the user has already
        // initiated a close (stop/X/lock-screen), a late
        // `.binduPlaybackComplete` from BinauralListener must NOT raise
        // the chamber on a dismissing view.
        guard store.isPresentingPlayer, !showingIntegration else { return }
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
        // The chamber only opens on natural completion, so this close
        // always represents a finished session — regardless of whether
        // the user saved a note or just closed.
        store.closePlayer(completed: true)
    }
}


private struct InfoChip: View {
    let label: String
    let value: String
    @Environment(\.binduTheme) private var theme

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
