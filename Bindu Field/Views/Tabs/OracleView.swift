import SwiftUI

struct OracleView: View {
    @State private var store = PlayerStore.shared
    @State private var input: String = ""
    @State private var viewState: ViewState = .idle
    @State private var hasKey: Bool = KeychainHelper.hasKey
    @State private var showingSettings = false
    @FocusState private var inputFocused: Bool

    private let theme = ThemeData.void

    enum ViewState {
        case idle
        case loading
        case result(track: Track, why: String)
        case error(String)
    }

    private var isLoading: Bool {
        if case .loading = viewState { return true }
        return false
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            if !hasKey {
                noKeyView
            } else {
                readyView
            }
        }
        .onAppear {
            // Re-check when tab is shown (in case user just set key in Settings)
            hasKey = KeychainHelper.hasKey
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Refresh after Settings dismiss in case user just added a key
            hasKey = KeychainHelper.hasKey
        }) {
            SettingsView()
        }
    }

    private var noKeyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ear")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(theme.subtle)
            Text("The Oracle awaits a key.")
                .font(.system(size: 17, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
            Button(action: { showingSettings = true }) {
                Text("Add API Key →")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.bg)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.text))
            }
            .buttonStyle(.plain)
            Text("Get a key at console.anthropic.com.")
                .font(.system(size: 11))
                .foregroundColor(theme.subtle)
        }
    }

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Oracle")
                        .font(.system(size: 32, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("speak, and you will be met")
                        .font(.system(size: 14))
                        .foregroundColor(theme.muted)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    TextField("how are you arriving?", text: $input, axis: .vertical)
                        .font(.system(size: 16, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                        .focused($inputFocused)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(theme.muted.opacity(0.2), lineWidth: 1)
                                )
                        )

                    Button(action: ask) {
                        Text(isLoading ? "listening..." : "listen")
                            .font(.system(size: 16, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(theme.bg)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().fill(
                                    (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                                    ? theme.muted.opacity(0.3) : theme.text
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal, 20)

                switch viewState {
                case .idle:
                    EmptyView()
                case .loading:
                    loadingView
                case .result(let track, let why):
                    resultView(track: track, why: why)
                case .error(let msg):
                    errorView(msg)
                }

                Spacer().frame(height: 60)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(theme.accent)
                .scaleEffect(1.1)
            Text("the Oracle is listening")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(theme.subtle)
        }
        .padding(.top, 16)
    }

    private func resultView(track: Track, why: String) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(track.verb)
                    .font(.system(size: 32, weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Text("\(track.song) — \(track.artist)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.muted)
            }

            Text(why)
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundColor(theme.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { store.play(track) }) {
                Text("Begin")
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.bg)
                    .padding(.horizontal, 56)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(theme.text))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(theme.muted.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.red.opacity(0.7))
            Text(msg)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 16)
    }

    private func ask() {
        inputFocused = false
        let userInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }
        viewState = .loading

        let catalog = CatalogStore.shared.tracks

        Task {
            do {
                let response = try await OracleService.shared.ask(userInput, allTracks: catalog)
                // Track.id is Int in our model; OracleResponse.trackID is String — stringify for compare.
                if let track = catalog.first(where: { String($0.id) == response.trackID }) {
                    await MainActor.run { viewState = .result(track: track, why: response.why) }
                } else {
                    await MainActor.run { viewState = .error("Oracle recommended an unknown track ID: \(response.trackID)") }
                }
            } catch let error as OracleError {
                await MainActor.run { viewState = .error(error.errorDescription ?? "Unknown error") }
            } catch {
                await MainActor.run { viewState = .error(error.localizedDescription) }
            }
        }
    }
}
