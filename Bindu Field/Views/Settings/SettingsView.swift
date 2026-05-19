import SwiftUI

struct SettingsView: View {
    @State private var settings = SettingsStore.shared
    @State private var sessions = SessionStore.shared
    @State private var showingClearConfirm = false
    @State private var showingKeyAlert = false
    @State private var tempKeyInput: String = ""
    @State private var keyDisplay: String? = KeychainHelper.masked()
    @Environment(\.dismiss) private var dismiss

    private let theme = ThemeData.void

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = dict?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
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
    private let theme = ThemeData.void

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
    private let theme = ThemeData.void

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
