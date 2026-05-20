import SwiftUI

/// Three modes of being. The field never stops; the Bindu always moves.
///
/// FIELD    — minimal. Visualizer dominant. Verb + song + recognition +
///            scrubber visible. Tap the background to surface CONTROL.
/// CONTROL  — 55%-height bottom sheet. Play/pause, binaural, in-session
///            BEAT slider, CARRIER readout with DERIVED chip, READING +
///            END SESSION buttons. 4s of no interaction returns to FIELD.
/// READING  — 80%-height bottom sheet. Recognition header + 4-tab bar
///            (WORDS / FREQUENCY / VIDEO / LALITA). Tap the dimmed
///            visualizer above the sheet to step back to CONTROL.
///
/// The binaural pill is anchored at the very top, always interactive,
/// outside the mode-transition envelope.
struct PlayerView: View {
    let track: Track

    @State private var store = PlayerStore.shared
    @State private var trackPlayer = TrackPlaybackService.shared
    @State private var wire = DSPWireService.shared

    @State private var hasArrived: Bool = false

    // Mode + auto-hide
    @State private var mode: PlayerMode = .field
    @State private var controlAutoHideTask: Task<Void, Never>?

    // Reading tab selection
    @State private var readingTab: ReadingTab = .words

    // Binaural pill breathing phase — flipped once on appear so the
    // 6pt dot's repeatForever animation kicks off when the pill renders.
    @State private var pillBreathePhase: Bool = false

    // CONTROL-sheet toggle-row dot breathing phase. Same pattern as the
    // pill: flipped on appear, kicks off a repeatForever scale animation.
    @State private var ctrlDotBreathePhase: Bool = false

    // Integration Chamber
    @State private var showingIntegration: Bool = false
    @State private var integrationText: String = ""
    @State private var integrationDismissTask: Task<Void, Never>?

    @Environment(\.binduTheme) private var theme

    enum PlayerMode { case field, control, reading }

    enum ReadingTab: String, CaseIterable, Identifiable {
        case words = "WORDS"
        case frequency = "FREQUENCY"
        case video = "VIDEO"
        case lalita = "LALITA"
        var id: String { rawValue }
    }

    private var elementColor: Color { Color.bindu(element: track.element) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                background

                // Mode-aware visualizer. Always rendered; size + position +
                // opacity respond to mode transitions.
                visualizerLayer(in: geo)

                // Bottom gradient — fades the visualizer's lower edge into
                // the bg around the 48–57% mark so the verb floats over a
                // softened canvas instead of sitting on a hard horizontal
                // line. FIELD mode only; CONTROL/READING use their own
                // sheet surfaces to mask the lower viz area.
                if mode == .field {
                    bottomFadeGradient(in: geo)
                }

                // FIELD content (verb / song / recognition / scrubber).
                // Now a ZStack overlay floating over the visualizer's
                // lower edge — verb anchored ~56% from the top, scrubber
                // pinned to the bottom.
                fieldContent(in: geo)
                    .opacity(mode == .field ? 1.0 : 0)
                    .animation(.easeInOut(duration: 0.32), value: mode)
                    .allowsHitTesting(mode == .field)

                // Mode-specific tap zones (above any sheets).
                modeTapZone(in: geo)

                // Top gradient — fades the bg-color over the top 88pt for
                // status-bar legibility, masking any cathedral arches that
                // reach the upper edge of the viz. Always present; sits
                // above the tap zone but below the pill / sheets.
                topStatusBarGradient
                    .allowsHitTesting(false)

                // CONTROL sheet — surfaces in CONTROL and READING (READING
                // overlays a taller sheet on top).
                if mode == .control || mode == .reading {
                    VStack(spacing: 0) {
                        Spacer()
                        controlSheet
                            .frame(height: geo.size.height * 0.55)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // READING sheet — covers CONTROL.
                if mode == .reading {
                    VStack(spacing: 0) {
                        Spacer()
                        readingSheet
                            .frame(height: geo.size.height * 0.80)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Binaural pill — always anchored top, always interactive.
                VStack(spacing: 0) {
                    binauralPill
                        .padding(.top, 56)
                    Spacer()
                }

                // Always-accessible close — visible in every mode, top
                // trailing. Sits above the pill row so it isn't shadowed
                // by the centred pill's hit area.
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { store.closePlayer() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .light))
                                .foregroundStyle(theme.subtle)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 52)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }

                // Loading state overlays everything when fetching audio
                if store.isLoadingTrack {
                    loadingView
                }

                if showingIntegration {
                    integrationChamber
                        .transition(.opacity)
                }
            }
            .opacity(hasArrived ? 1.0 : 0)
            .scaleEffect(hasArrived ? 1.0 : 0.96)
            .animation(.easeOut(duration: 0.6), value: hasArrived)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: mode)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation { hasArrived = true }
        }
        .onDisappear {
            controlAutoHideTask?.cancel()
            integrationDismissTask?.cancel()
        }
        .onChange(of: trackPlayer.hasCompleted) { _, completed in
            if completed { presentIntegration() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .binduPlaybackComplete)) { _ in
            presentIntegration()
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [elementColor.opacity(0.14), theme.bg],
                center: .center,
                startRadius: 60,
                endRadius: 540
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Visualizer (mode-aware)
    //
    // Phase 5: the Cathedral renderer needs a wide-and-short canvas (the
    // cathedral floor + Sid columns + vault all reference the canvas's
    // own width). Anchor top, full-width, height per mode.

    @ViewBuilder
    private func visualizerLayer(in geo: GeometryProxy) -> some View {
        let h = visualizerHeight(for: mode, in: geo.size)
        let dim = visualizerOpacity(for: mode)

        VStack(spacing: 0) {
            VisualizerView(color: elementColor, elementHueDeg: elementHueDeg)
                .frame(maxWidth: .infinity)
                .frame(height: h)
                .opacity(dim)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: mode)
    }

    private func visualizerHeight(for mode: PlayerMode, in size: CGSize) -> CGFloat {
        switch mode {
        case .field:   return size.height * 0.60
        case .control: return size.height * 0.45
        case .reading: return size.height * 0.20
        }
    }

    private func visualizerOpacity(for mode: PlayerMode) -> Double {
        switch mode {
        case .field:   return 1.0
        case .control: return 0.55
        case .reading: return 0.32
        }
    }

    // MARK: - FIELD content
    //
    // ZStack overlay on top of the visualizer area. The text block (verb,
    // song · artist, recognition) is anchored ~56% from the top so it
    // floats over the visualizer's lower edge where the bottom gradient
    // fades the viz into the bg. The scrubber is anchored to the bottom
    // of the screen, independent of the text block.

    @ViewBuilder
    private func fieldContent(in geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Text block — verb is the primary gesture.
            VStack(spacing: 0) {
                Text(track.verb)
                    .font(.system(size: 62, weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundColor(elementColor)
                    .shadow(color: elementColor.opacity(0.5), radius: 22)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                Text("\(track.song) — \(track.artist)")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle)
                    .padding(.bottom, 12)

                if let rs = track.recognitionStatement, !rs.isEmpty {
                    Text("\u{201C}\(rs)\u{201D}")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundColor(theme.text.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 38)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, geo.size.height * 0.56)

            // Scrubber pinned to the bottom of the screen.
            VStack(spacing: 0) {
                Spacer()
                slimScrubber
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gradient overlays

    @ViewBuilder
    private func bottomFadeGradient(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: geo.size.height * 0.48)
            LinearGradient(
                colors: [Color.clear, theme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 86)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var topStatusBarGradient: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [theme.bg.opacity(0.80), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 88)
            Spacer()
        }
    }

    // Read-only "flowing" scrubber. Slim (2pt), element-color fill.
    @ViewBuilder
    private var slimScrubber: some View {
        let elapsed = trackPlayer.elapsed
        let duration = max(trackPlayer.duration, 0.1)
        let progress = min(max(elapsed / duration, 0), 1)

        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 2)
                    Capsule()
                        .fill(elementColor)
                        .frame(width: geo.size.width * progress, height: 2)
                        .shadow(color: elementColor.opacity(0.35), radius: 4)
                    Circle()
                        .fill(elementColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: elementColor.opacity(0.55), radius: 5)
                        .offset(x: geo.size.width * progress - 4)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                Text("flowing")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.subtle.opacity(0.55))
            }
        }
    }

    // MARK: - Mode tap zones

    /// Captures background taps appropriate to the current mode. Sheets
    /// render above this layer so the sheet's own controls aren't
    /// short-circuited.
    @ViewBuilder
    private func modeTapZone(in geo: GeometryProxy) -> some View {
        switch mode {
        case .field:
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { enterControl() }
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            if value.translation.height > 60 && mode == .field {
                                store.closePlayer()
                            }
                        }
                )
        case .control:
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: geo.size.height * 0.45)
                    .contentShape(Rectangle())
                    .onTapGesture { returnToField() }
                Spacer(minLength: 0)
            }
        case .reading:
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: geo.size.height * 0.20)
                    .contentShape(Rectangle())
                    .onTapGesture { enterControl() }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - CONTROL sheet

    @ViewBuilder
    private var controlSheet: some View {
        ZStack(alignment: .top) {
            // Surface
            UnevenRoundedRectangle(
                topLeadingRadius: 32, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 32,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 32, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 32,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.04))
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 32, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 32,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 34, height: 3)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Play/Pause circle
                Button(action: {
                    trackPlayer.togglePlayPause()
                    scheduleAutoHide()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hue: elementHueDeg / 360, saturation: 0.32, brightness: 0.12))
                            .frame(width: 56, height: 56)
                        Circle()
                            .stroke(elementColor.opacity(0.42), lineWidth: 1)
                            .frame(width: 56, height: 56)
                        Image(systemName: trackPlayer.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(elementColor)
                            .offset(x: trackPlayer.isPaused ? 2 : 0)
                    }
                    .shadow(color: elementColor.opacity(0.28), radius: 14)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)

                // BINAURAL section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("BINAURAL")
                            .font(.system(size: 9, weight: .light))
                            .tracking(2.2)
                            .foregroundColor(theme.subtle.opacity(0.6))
                        Spacer()
                    }

                    // Toggle row
                    binauralToggleRow

                    // PRESENCE
                    sliderRow(
                        label: "PRESENCE",
                        value: Binding(
                            get: { Double(wire.userPresence) },
                            set: { wire.userPresence = Float($0); scheduleAutoHide() }
                        ),
                        range: 0...1,
                        displayText: "\(Int(wire.userPresence * 100))%"
                    )

                    // BEAT — adjustable in-session
                    beatSliderRow

                    // CARRIER readout
                    carrierRow
                }
                .padding(.horizontal, 26)

                Spacer(minLength: 0)

                // Bottom buttons
                HStack(spacing: 10) {
                    Button(action: { enterReading(); scheduleAutoHide() }) {
                        Text("READING")
                            .font(.system(size: 10, weight: .regular))
                            .tracking(1.6)
                            .foregroundColor(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.closePlayer() }) {
                        Text("END SESSION")
                            .font(.system(size: 10, weight: .regular))
                            .tracking(1.4)
                            .foregroundColor(theme.subtle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 28)
            }
        }
        .contentShape(Rectangle())
        // Any tap inside the sheet that isn't a control resets the timer.
        .simultaneousGesture(TapGesture().onEnded { scheduleAutoHide() })
    }

    private var binauralToggleRow: some View {
        HStack(spacing: 12) {
            // Custom toggle (44x24)
            Button {
                wire.binauralEnabled.toggle()
                scheduleAutoHide()
            } label: {
                ZStack(alignment: wire.binauralEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(wire.binauralEnabled
                              ? elementColor
                              : Color.white.opacity(0.10))
                        .frame(width: 44, height: 24)
                        .shadow(color: wire.binauralEnabled ? elementColor.opacity(0.30) : .clear, radius: 8)
                    Circle()
                        .fill(theme.bg)
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 2)
                }
                .animation(.easeInOut(duration: 0.28), value: wire.binauralEnabled)
            }
            .buttonStyle(.plain)

            Text(wire.binauralEnabled ? "ON" : "OFF")
                .font(.system(size: 10, weight: .regular))
                .tracking(1.4)
                .foregroundColor(wire.binauralEnabled ? theme.muted : theme.subtle)

            Spacer()

            // Breathing dot — appears when binaural is on and breathes
            // continuously at a 2s cycle. Shows that binaural is alive.
            // (The 500ms carrier-derivation pulse lives on the binaural
            // pill at the top and in the CARRIER row's DERIVED chip; this
            // dot is purely an "on" indicator.)
            if wire.binauralEnabled {
                Circle()
                    .fill(elementColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: elementColor.opacity(0.55), radius: 4)
                    .scaleEffect(ctrlDotBreathePhase ? 1.15 : 1.0)
                    .opacity(ctrlDotBreathePhase ? 1.0 : 0.65)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                               value: ctrlDotBreathePhase)
                    .onAppear { ctrlDotBreathePhase = true }
                    .onDisappear { ctrlDotBreathePhase = false }
            }
        }
    }

    // Reusable hairline-slider row
    @ViewBuilder
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayText: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .tracking(2.0)
                .foregroundColor(theme.subtle)
                .frame(width: 68, alignment: .leading)

            GeometryReader { geo in
                let pct = CGFloat((value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.13)).frame(height: 1)
                    Capsule()
                        .fill(elementColor)
                        .frame(width: max(0, pct * geo.size.width), height: 1)
                        .shadow(color: elementColor.opacity(0.35), radius: 3)
                    Circle()
                        .fill(elementColor)
                        .frame(width: 13, height: 13)
                        .shadow(color: elementColor.opacity(0.45), radius: 6)
                        .offset(x: pct * geo.size.width - 6.5)
                        .allowsHitTesting(false)
                    Slider(value: value, in: range)
                        .opacity(0.01)
                        .frame(height: 24)
                }
                .frame(height: 24)
            }
            .frame(height: 24)

            Text(displayText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.muted)
                .frame(width: 46, alignment: .trailing)
        }
    }

    // BEAT slider with zone ticks (Δ / Θ / α) + state badge
    @ViewBuilder
    private var beatSliderRow: some View {
        let beatMin: Float = 0.5, beatMax: Float = 30
        let zones: [(hz: Float, label: String)] = [
            (4, "Δ"), (8, "Θ"), (13, "α")
        ]
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("BEAT")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.0)
                    .foregroundColor(theme.subtle)
                    .frame(width: 68, alignment: .leading)

                GeometryReader { geo in
                    let v = wire.userBeatHz
                    let pct = CGFloat((v - beatMin) / (beatMax - beatMin))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.13)).frame(height: 1)
                        Capsule()
                            .fill(elementColor)
                            .frame(width: max(0, pct * geo.size.width), height: 1)
                        // Zone ticks
                        ForEach(zones, id: \.hz) { z in
                            let zPct = CGFloat((z.hz - beatMin) / (beatMax - beatMin))
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 1, height: 5)
                                .offset(x: zPct * geo.size.width - 0.5)
                        }
                        Circle()
                            .fill(elementColor)
                            .frame(width: 13, height: 13)
                            .shadow(color: elementColor.opacity(0.45), radius: 6)
                            .offset(x: pct * geo.size.width - 6.5)
                            .allowsHitTesting(false)
                        Slider(value: Binding(
                            get: { Double(wire.userBeatHz) },
                            set: { wire.userBeatHz = Float($0); scheduleAutoHide() }
                        ), in: Double(beatMin)...Double(beatMax))
                        .opacity(0.01)
                        .frame(height: 28)
                    }
                    .frame(height: 28)
                }
                .frame(height: 28)

                Text(String(format: "%.1f Hz", wire.userBeatHz))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.muted)
                    .frame(width: 44, alignment: .trailing)

                Text(brainwaveLabel(for: wire.userBeatHz))
                    .font(.system(size: 8, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(elementColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hue: elementHueDeg / 360, saturation: 0.38, brightness: 0.13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(elementColor.opacity(0.42), lineWidth: 1)
                            )
                    )
                    .frame(minWidth: 44)
            }
            // Zone label strip
            HStack(spacing: 0) {
                Spacer().frame(width: 76)
                GeometryReader { geo in
                    ZStack {
                        ForEach(zones, id: \.hz) { z in
                            let zPct = CGFloat((z.hz - beatMin) / (beatMax - beatMin))
                            Text(z.label)
                                .font(.system(size: 8))
                                .foregroundColor(theme.subtle.opacity(0.55))
                                .position(x: zPct * geo.size.width, y: 6)
                        }
                    }
                }
                .frame(height: 12)
                Spacer().frame(width: 96)
            }
        }
    }

    private var carrierRow: some View {
        HStack(spacing: 8) {
            Text("CARRIER")
                .font(.system(size: 9, weight: .light))
                .tracking(2.0)
                .foregroundColor(theme.subtle)
                .frame(width: 68, alignment: .leading)
            Text(String(format: "%.1f Hz", wire.currentCarrierHz))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(theme.muted)
            Spacer()
            if wire.hasDerivedCarrier {
                Text("DERIVED")
                    .font(.system(size: 8, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(elementColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hue: elementHueDeg / 360, saturation: 0.38, brightness: 0.13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(elementColor.opacity(0.42), lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: wire.hasDerivedCarrier)
    }

    // MARK: - READING sheet

    @ViewBuilder
    private var readingSheet: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 32, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 32,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 32, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 32,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.04))
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 32, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 32,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 34, height: 3)
                    .padding(.top, 12)

                // Recognition header
                if let rs = track.recognitionStatement, !rs.isEmpty {
                    Text("\u{201C}\(rs)\u{201D}")
                        .font(.system(size: 17, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(elementColor)
                        .shadow(color: elementColor.opacity(0.35), radius: 18)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                }

                // Tab bar
                HStack(spacing: 0) {
                    ForEach(ReadingTab.allCases) { tab in
                        Button(action: { readingTab = tab }) {
                            VStack(spacing: 10) {
                                Text(tab.rawValue)
                                    .font(.system(size: 9, weight: .regular))
                                    .tracking(1.8)
                                    .foregroundColor(readingTab == tab ? theme.text : theme.subtle)
                                Rectangle()
                                    .fill(readingTab == tab ? elementColor : Color.clear)
                                    .frame(height: 1.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }

                // Tab content
                ScrollView {
                    Group {
                        switch readingTab {
                        case .words:
                            wordsContent
                        case .frequency:
                            frequencyContent
                        case .video:
                            videoContent
                        case .lalita:
                            lalitaContent
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Reading tab contents

    @ViewBuilder
    private var wordsContent: some View {
        ReadingContent(
            text: track.lyricalWordsReading,
            empty: "the words reading for this song is still forming.",
            theme: theme,
            elementColor: elementColor
        )
    }

    @ViewBuilder
    private var frequencyContent: some View {
        let chakraProto: ChakraProtocol? = track.chakra.flatMap { ChakraData.all[$0] }
        VStack(spacing: 0) {
            FrequencyRow(label: "State",   value: track.state.rawValue.uppercased())
            FrequencyRow(label: "Beat",    value: String(format: "%.1f Hz · %@", wire.userBeatHz, brainwaveLabel(for: wire.userBeatHz)))
            FrequencyRow(label: "Carrier", value: String(format: "%.1f Hz", wire.currentCarrierHz))
            FrequencyRow(label: "Element", value: track.element)
            if let p = chakraProto {
                FrequencyRow(
                    label: "Breath",
                    value: "\(p.inhale)s · hold \(p.hold)s · exhale \(p.exhale)s"
                )
            }
            // Frequency reading prose, if present
            if !track.frequencyReading.isEmpty {
                Text(track.frequencyReading)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
                    .lineSpacing(5)
                    .padding(.top, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if track.videoPulseReading.isEmpty {
            VStack {
                Text("video arrives in a future session")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 1))
            )
        } else {
            ReadingContent(
                text: track.videoPulseReading,
                empty: "",
                theme: theme,
                elementColor: elementColor
            )
        }
    }

    @ViewBuilder
    private var lalitaContent: some View {
        if let l = track.lalitasPerspective, !l.isEmpty {
            ReadingContent(
                text: l,
                empty: "",
                theme: theme,
                elementColor: elementColor
            )
        } else {
            VStack(alignment: .leading, spacing: 24) {
                Text("the Lalita reading for this song is still forming. what you've brought to it is part of the reading.")
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
                    .lineSpacing(6)
                Text("return when the field calls you back.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle.opacity(0.6))
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Binaural pill (status indicator, anchored top)
    //
    // The pill is purely a status indicator + an entry point into the
    // CONTROL sheet where the real binaural controls live. It shows the
    // 6pt breathing dot (filled element-color when binaural is on,
    // outlined when off), the "BINAURAL" label, and a "›" chevron
    // signalling "more elsewhere". Tapping anywhere on it enters
    // CONTROL mode.

    private var binauralPill: some View {
        let on = wire.binauralEnabled
        return Button(action: { enterControl() }) {
            HStack(spacing: 7) {
                Circle()
                    .fill(on ? elementColor : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(theme.subtle.opacity(on ? 0 : 0.65), lineWidth: 1)
                    )
                    .frame(width: 6, height: 6)
                    .shadow(color: on ? elementColor.opacity(0.45) : .clear, radius: 6)
                    .scaleEffect(on && pillBreathePhase ? 1.25 : 1.0)
                    .opacity(on ? (pillBreathePhase ? 1.0 : 0.7) : 1.0)
                Text("BINAURAL")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.0)
                    .foregroundColor(theme.subtle)
                Text("›")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(theme.subtle.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(theme.muted.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                   value: pillBreathePhase)
        .onAppear { pillBreathePhase = true }
    }

    // MARK: - Loading + Integration

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.opacity(0.85))
    }

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

    // MARK: - Mode transitions

    private func enterControl() {
        guard mode != .control else { return }
        mode = .control
        scheduleAutoHide()
    }

    private func enterReading() {
        guard mode != .reading else { return }
        controlAutoHideTask?.cancel()
        mode = .reading
    }

    private func returnToField() {
        guard mode != .field else { return }
        controlAutoHideTask?.cancel()
        mode = .field
    }

    private func scheduleAutoHide() {
        controlAutoHideTask?.cancel()
        controlAutoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled, mode == .control {
                returnToField()
            }
        }
    }

    // MARK: - Integration Chamber lifecycle

    private func presentIntegration() {
        guard store.isPresentingPlayer, !showingIntegration else { return }
        showingIntegration = true
        integrationText = ""

        integrationDismissTask?.cancel()
        integrationDismissTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    if showingIntegration { dismissIntegration(save: false) }
                }
            }
        }
    }

    private func dismissIntegration(save: Bool) {
        integrationDismissTask?.cancel()
        integrationDismissTask = nil
        if save {
            let trimmed = integrationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { store.pendingNote = trimmed }
        }
        showingIntegration = false
        store.closePlayer(completed: true)
    }

    // MARK: - Helpers

    /// HSB hue of the element's color, in degrees, for tinted material
    /// shades that need the same hue at different brightness/saturation
    /// (the small badge pills behind DERIVED / state labels).
    private var elementHueDeg: Double {
        switch track.element {
        case "Earth":       return 15
        case "Water":       return 210
        case "Fire":        return 25
        case "Air":         return 195
        case "Light":       return 50
        case "Crown":       return 280
        case "Soul":        return 265
        case "Dissolution": return 190
        case "Family":      return 330
        default:            return 280
        }
    }

    private func brainwaveLabel(for hz: Float) -> String {
        switch hz {
        case ..<4:  return "DELTA"
        case ..<8:  return "THETA"
        case ..<13: return "ALPHA"
        case ..<30: return "BETA"
        default:    return "GAMMA"
        }
    }
}

// MARK: - Reading helpers (private structs)

private struct ReadingContent: View {
    let text: String
    let empty: String
    let theme: Theme
    let elementColor: Color

    var body: some View {
        if text.isEmpty {
            if !empty.isEmpty {
                Text(empty)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            // Render paragraphs split on blank lines. Last paragraph
            // surfaces in element color as a closing gesture.
            let paragraphs = text
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, p in
                    let isLast = (idx == paragraphs.count - 1) && paragraphs.count > 1
                    Text(p)
                        .font(.system(size: 15, design: .serif))
                        .italic()
                        .foregroundColor(isLast ? elementColor : theme.muted)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, isLast ? 18 : 0)
                        .overlay(alignment: .top) {
                            if isLast {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FrequencyRow: View {
    let label: String
    let value: String
    @Environment(\.binduTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .light))
                .tracking(1.8)
                .foregroundColor(theme.subtle)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(theme.muted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }
}
