import SwiftUI

/// Four-state Oracle. The void is the ground; the presence is always
/// rendered behind whichever state is foregrounded.
enum OracleUIState {
    case idle       // void with barely-visible presence
    case typing     // question forms — no input box, just words
    case waiting    // question dissolves, Oracle processes
    case response   // verb + track + why arrive
}

struct OracleView: View {
    @State private var uiState: OracleUIState = .idle
    @State private var presence = OraclePresenceModel()
    @State private var question: String = ""
    @State private var response: (track: Track, why: String)? = nil
    @State private var errorMessage: String? = nil
    @State private var hasKey: Bool = KeychainHelper.hasKey
    @State private var showingSettings = false

    @State private var store = PlayerStore.shared
    @State private var sessionStore = SessionStore.shared
    @State private var catalog = CatalogStore.shared

    @Environment(\.binduTheme) private var theme

    /// Up to 10 most-recent track IDs from session history, deduplicated
    /// in recency order. Empty → the deprioritize hint is skipped.
    private var recentTrackIDs: [Int] {
        Array(
            sessionStore.sessions
                .filter { $0.type == .track }
                .compactMap { Int($0.sourceID) }
                .uniqued()
                .prefix(10)
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#020208").ignoresSafeArea()

            if hasKey {
                OraclePresenceView(model: presence)

                switch uiState {
                case .idle:
                    IdleContent(onActivate: { enterTyping() })
                case .typing:
                    TypingContent(
                        question: $question,
                        onSubmit: { submitQuestion() }
                    )
                case .waiting:
                    WaitingContent()
                case .response:
                    if let r = response {
                        ResponseContent(
                            track: r.track,
                            why: r.why,
                            onEnterField: { enterField(track: r.track) },
                            onAskAgain: { resetToIdle() }
                        )
                    }
                }

                if let msg = errorMessage {
                    ErrorOverlay(message: msg, onDismiss: { resetToIdle() })
                }
            } else {
                noKeyView
            }
        }
        .onAppear {
            hasKey = KeychainHelper.hasKey
            presence.isActive = true
        }
        .onDisappear {
            presence.isActive = false
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            hasKey = KeychainHelper.hasKey
        }) {
            SettingsView()
        }
    }

    // MARK: — Transitions

    private func enterTyping() {
        withAnimation(.easeInOut(duration: 0.45)) {
            uiState = .typing
        }
    }

    private func submitQuestion() {
        let userInput = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }
        errorMessage = nil

        withAnimation(.easeInOut(duration: 0.45)) {
            uiState = .waiting
        }

        let catalogTracks = catalog.tracks
        let recent = recentTrackIDs

        Task {
            do {
                let result = try await OracleService.shared.ask(
                    userInput,
                    allTracks: catalogTracks,
                    recentlyPlayed: recent
                )
                if let track = catalogTracks.first(where: { String($0.id) == result.trackID }) {
                    let hue = Color.binduHue(element: track.element)
                    await MainActor.run {
                        presence.responseHue = hue
                        response = (track: track, why: result.why)
                        withAnimation(.easeInOut(duration: 0.45)) {
                            uiState = .response
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "the Oracle returned an unknown track"
                        withAnimation(.easeInOut(duration: 0.35)) {
                            uiState = .idle
                        }
                    }
                }
            } catch let error as OracleError {
                await MainActor.run {
                    errorMessage = error.errorDescription ?? "the Oracle is silent"
                    withAnimation(.easeInOut(duration: 0.35)) {
                        uiState = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    withAnimation(.easeInOut(duration: 0.35)) {
                        uiState = .idle
                    }
                }
            }
        }
    }

    private func enterField(track: Track) {
        store.play(track)
        // Reset Oracle state so the next visit starts in the void.
        resetToIdle()
    }

    private func resetToIdle() {
        withAnimation(.easeInOut(duration: 0.4)) {
            uiState = .idle
        }
        question = ""
        response = nil
        errorMessage = nil
        presence.responseHue = nil
    }

    // MARK: — No-key gate

    private var noKeyView: some View {
        VStack(spacing: 20) {
            Text("THE ORACLE")
                .font(.system(size: 8, weight: .light))
                .tracking(4.0)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.40))
            Text("the Oracle awaits a key")
                .font(.system(size: 16, design: .serif).italic())
                .foregroundStyle(theme.muted)
            Button(action: { showingSettings = true }) {
                Text("ADD API KEY")
                    .font(.system(size: 10, weight: .light))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .overlay(
                        Capsule().stroke(theme.text.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Text("get a key at console.anthropic.com")
                .font(.system(size: 10, design: .serif).italic())
                .foregroundStyle(theme.subtle)
        }
    }
}

// MARK: — Idle

private struct IdleContent: View {
    let onActivate: () -> Void
    @State private var showAffordance = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onActivate() }

            // "THE ORACLE" centered, fades in at 2.2s and breathes slowly.
            VStack {
                Spacer()
                Text("THE ORACLE")
                    .font(.system(size: 7, weight: .light))
                    .tracking(5.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hex: "#F5E2D6")
                            .opacity(showAffordance ? 0.35 : 0)
                    )
                Spacer()
            }
            .animation(.easeInOut(duration: 2.0), value: showAffordance)

            // ◌ glyph at bottom, fades in just after the label.
            VStack {
                Spacer()
                Text("◌")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        Color(hex: "#F5E2D6")
                            .opacity(showAffordance ? 0.28 : 0)
                    )
                    .padding(.bottom, 92)
            }
            .animation(.easeInOut(duration: 2.0).delay(0.5), value: showAffordance)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                showAffordance = true
            }
        }
    }
}

// MARK: — Typing

private struct TypingContent: View {
    @Binding var question: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    private var trimmed: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THE ORACLE")
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(4.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.35))
                    .padding(.leading, 24)
                    .padding(.top, 22)
                Spacer()
            }

            Spacer()

            TextField("", text: $question, axis: .vertical)
                .focused($focused)
                .font(.system(size: 26, weight: .light, design: .serif).italic())
                .foregroundStyle(Color(hex: "#F5E2D6"))
                .multilineTextAlignment(.center)
                .tint(Color(hex: "#F5E2D6").opacity(0.65))
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .lineLimit(4)
                .padding(.horizontal, 40)

            Button(action: { if !trimmed.isEmpty { onSubmit() } }) {
                Text("ASK")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        Color(hex: "#F5E2D6")
                            .opacity(trimmed.isEmpty ? 0.30 : 0.55)
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#F5E2D6").opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .padding(.top, 40)

            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: — Waiting

private struct WaitingContent: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#F5E2D6").opacity(0.35))
                    .frame(width: 4, height: 4)
                    .scaleEffect(phase ? 1.0 : 0.6)
                    .opacity(phase ? 0.80 : 0.30)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.25),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
    }
}

// MARK: — Response

private struct ResponseContent: View {
    let track: Track
    let why: String
    let onEnterField: () -> Void
    let onAskAgain: () -> Void

    @State private var showVerb = false
    @State private var showTrack = false
    @State private var showWhy = false
    @State private var showButtons = false

    private var hue: Double { Color.binduHue(element: track.element) }
    private var verbColor: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.68)
    }
    private var verbGlow: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.60)
    }
    private var ctaStroke: Color {
        Color(hue: hue / 360, saturation: 0.45, brightness: 0.55).opacity(0.22)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top label persists in response too — anchor for the void.
            HStack {
                Text("THE ORACLE")
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(4.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.35))
                    .padding(.leading, 24)
                    .padding(.top, 22)
                Spacer()
            }

            Spacer()

            if showVerb {
                Text(track.verb)
                    .font(.system(size: 72, weight: .light, design: .serif).italic())
                    .foregroundStyle(verbColor)
                    .shadow(color: verbGlow.opacity(0.35), radius: 30)
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
                    .padding(.bottom, 28)
            }

            if showTrack {
                Text(track.song)
                    .font(.system(size: 20, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.7))
                    .transition(.opacity)
                    .padding(.bottom, 18)
            }

            if showWhy {
                Rectangle()
                    .fill(Color(hex: "#F5E2D6").opacity(0.06))
                    .frame(width: 40, height: 1)
                    .padding(.bottom, 16)
                    .transition(.opacity)

                Text(why)
                    .font(.system(size: 15, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.52))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 320)
                    .transition(.opacity)
                    .padding(.bottom, 42)
            }

            if showButtons {
                HStack(spacing: 16) {
                    Button(action: onEnterField) {
                        Text("ENTER THE FIELD")
                            .font(.system(size: 9, weight: .light))
                            .tracking(2.2)
                            .textCase(.uppercase)
                            .foregroundStyle(verbColor)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .overlay(Capsule().stroke(ctaStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: onAskAgain) {
                        Text("ask again")
                            .font(.system(size: 11, weight: .light, design: .serif).italic())
                            .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .onAppear { startArrivalSequence() }
    }

    private func startArrivalSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.9)) {
                showVerb = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 1.0)) {
                showTrack = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.easeOut(duration: 1.4)) {
                showWhy = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
            withAnimation(.easeOut(duration: 1.0)) {
                showButtons = true
            }
        }
    }
}

// MARK: — Error overlay (quiet, dismissable)

private struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 13, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.55))
                    .multilineTextAlignment(.center)
                Button(action: onDismiss) {
                    Text("dismiss")
                        .font(.system(size: 9, weight: .light))
                        .tracking(2.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.45))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color(hex: "#F5E2D6").opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 60)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}

// MARK: — Helpers

private extension Array where Element: Hashable {
    /// Order-preserving deduplication. Used to collapse repeat-play
    /// history into a recency-sorted unique list.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
