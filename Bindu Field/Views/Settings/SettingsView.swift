import SwiftUI

struct SettingsView: View {
    @State private var settings = SettingsStore.shared
    @State private var sessions = SessionStore.shared
    @State private var catalog = CatalogStore.shared
    @State private var wire = DSPWireService.shared
    @State private var showingClearConfirm = false
    @State private var showingClearCacheConfirm = false
    @State private var showingKeyAlert = false
    @State private var tempKeyInput: String = ""
    @State private var keyDisplay: String? = KeychainHelper.masked()
    @State private var cacheBytes: Int = 0
    @State private var showDiagnostics: Bool = false
    @Environment(\.dismiss) private var dismiss

    @Environment(\.binduTheme) private var theme

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    @ViewBuilder
    private func diagnosticsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.text)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Audio
                        SettingsSection(title: "audio") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("gain")
                                        .font(.system(size: 13, design: .serif))
                                        .italic()
                                        .foregroundColor(theme.text)
                                    Spacer()
                                    Text(String(format: "%.0f%%", settings.gain * 100 / 0.10))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(theme.muted)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(settings.gain) },
                                        set: { settings.gain = Float($0) }
                                    ),
                                    in: 0.0...0.10
                                )
                                .tint(theme.accent)
                                Text("Affects all binaural playback. Default is around 40%.")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.subtle)
                            }
                        }

                        // Session
                        SettingsSection(title: "session") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("default duration")
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.text)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach([300, 600, 1200, 1800, 999999], id: \.self) { secs in
                                            DurationChip(
                                                label: secs == 999999 ? "∞" : "\(secs / 60) min",
                                                isSelected: Int(settings.defaultSessionDuration) == secs,
                                                action: { settings.defaultSessionDuration = TimeInterval(secs) }
                                            )
                                        }
                                    }
                                }

                                Text("Used as the starting duration when you open a track.")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.subtle)
                            }
                        }

                        // Oracle
                        SettingsSection(title: "oracle") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("claude api key")
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.text)

                                if let masked = keyDisplay {
                                    HStack {
                                        Text(masked)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(theme.muted)
                                        Spacer()
                                        Button("Replace") { showingKeyAlert = true }
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.accent)
                                            .buttonStyle(.plain)
                                        Button("Remove") {
                                            KeychainHelper.delete()
                                            keyDisplay = nil
                                        }
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.red.opacity(0.85))
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    Button("Add API Key") { showingKeyAlert = true }
                                        .font(.system(size: 13, design: .serif))
                                        .italic()
                                        .foregroundColor(theme.accent)
                                        .buttonStyle(.plain)
                                }

                                Text("Required for the Oracle tab. Get a key at console.anthropic.com. Stored in iOS Keychain on this device only.")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.subtle)
                            }
                        }

                        // Data
                        SettingsSection(title: "data") {
                            VStack(alignment: .leading, spacing: 14) {
                                Button(action: { showingClearConfirm = true }) {
                                    HStack {
                                        Text("clear archive")
                                            .font(.system(size: 13, design: .serif))
                                            .italic()
                                        Spacer()
                                        Text("\(sessions.sessions.count) session\(sessions.sessions.count == 1 ? "" : "s")")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(theme.subtle)
                                    }
                                    .foregroundColor(Color.red.opacity(0.85))
                                }
                                .buttonStyle(.plain)

                                // O12 / G5: clear cached audio. Surfaces
                                // current size so the user has a number to
                                // act on.
                                Button(action: { showingClearCacheConfirm = true }) {
                                    HStack {
                                        Text("clear audio cache")
                                            .font(.system(size: 13, design: .serif))
                                            .italic()
                                        Spacer()
                                        Text(formatBytes(cacheBytes))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(theme.subtle)
                                    }
                                    .foregroundColor(theme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Catalog (O12 / G12 / G14)
                        SettingsSection(title: "catalog") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("\(catalog.tracks.count) track\(catalog.tracks.count == 1 ? "" : "s")")
                                        .font(.system(size: 13, design: .serif))
                                        .italic()
                                        .foregroundColor(theme.text)
                                    Spacer()
                                    Button {
                                        Task { await catalog.refresh(force: true) }
                                    } label: {
                                        HStack(spacing: 6) {
                                            if catalog.isLoading {
                                                ProgressView().scaleEffect(0.7).tint(theme.accent)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 12))
                                            }
                                            Text("refresh")
                                                .font(.system(size: 12, design: .serif))
                                                .italic()
                                        }
                                        .foregroundColor(theme.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(catalog.isLoading)
                                }

                                if let when = catalog.lastRefreshedAt {
                                    Text("last refreshed \(DateFormatter.archiveTime.string(from: when))")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.subtle)
                                }

                                if catalog.isStaleFromCache, let err = catalog.loadError {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wifi.slash")
                                            .font(.system(size: 10))
                                        Text(err)
                                            .font(.system(size: 11, design: .serif))
                                            .italic()
                                            .lineLimit(2)
                                    }
                                    .foregroundColor(Color.orange.opacity(0.85))
                                }
                            }
                        }

                        // Diagnostics (G23) — hidden behind a tap on the
                        // version row. Useful on-device to confirm the DSP
                        // wire is actually doing work; not surfaced by default.
                        if showDiagnostics {
                            SettingsSection(title: "diagnostics") {
                                VStack(alignment: .leading, spacing: 4) {
                                    diagnosticsRow("dsp frames consumed", value: "\(wire.framesConsumed)")
                                    diagnosticsRow("dsp gain writes", value: "\(wire.gainWrites)")
                                    diagnosticsRow("dsp onsets seen", value: "\(wire.onsetCount)")
                                    diagnosticsRow("music playing", value: wire.isMusicPlaying ? "yes" : "no")
                                    diagnosticsRow("carrier locked", value: wire.carrierLocked ? "yes" : "no")
                                }
                            }
                        }

                        // About
                        SettingsSection(title: "about") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bindu Field")
                                    .font(.system(size: 14, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.text)
                                Text(appVersion)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(theme.muted)
                                    .onTapGesture(count: 3) {
                                        // G23: triple-tap the version to
                                        // reveal the DSP diagnostics panel.
                                        showDiagnostics.toggle()
                                    }
                                Text("A consciousness instrument.")
                                    .font(.system(size: 12, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.subtle)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "Clear all sessions?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear \(sessions.sessions.count) session\(sessions.sessions.count == 1 ? "" : "s")", role: .destructive) {
                    sessions.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your practice history. Cannot be undone.")
            }
            .confirmationDialog(
                "Clear cached audio?",
                isPresented: $showingClearCacheConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear \(formatBytes(cacheBytes))", role: .destructive) {
                    AudioCache.shared.purgeAll()
                    cacheBytes = AudioCache.shared.currentSizeBytes()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Downloaded mp3s will be re-fetched from the network the next time you open them.")
            }
            .onAppear {
                cacheBytes = AudioCache.shared.currentSizeBytes()
            }
            .alert("Claude API Key", isPresented: $showingKeyAlert) {
                SecureField("sk-ant-...", text: $tempKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") {
                    let trimmed = tempKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        KeychainHelper.save(trimmed)
                        keyDisplay = KeychainHelper.masked()
                    }
                    tempKeyInput = ""
                }
                Button("Cancel", role: .cancel) { tempKeyInput = "" }
            } message: {
                Text("Stored in iOS Keychain. Never leaves this device.")
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.binduTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .light))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundColor(theme.subtle)

            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.muted.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

private struct DurationChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.binduTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundColor(isSelected ? theme.bg : theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.text : Color.clear)
                        .overlay(Capsule().stroke(theme.muted.opacity(0.3), lineWidth: isSelected ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
    }
}
