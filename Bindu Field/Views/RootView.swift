import SwiftUI

struct RootView: View {
    @State private var nav = NavigationStore.shared
    @State private var store = PlayerStore.shared
    @State private var session = AudioSessionCoordinator.shared
    @State private var settings = SettingsStore.shared
    @Environment(\.colorScheme) private var systemScheme
    @State private var showBirthSequence: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.seen")
    @State private var showHeadphonesTip: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.tipSeen")

    /// The palette injected app-wide. The immersive Canvas tabs re-pin
    /// `void` below so they stay dark even when the user chooses Light.
    private var theme: Theme { settings.activeTheme(for: systemScheme) }

    var body: some View {
        ZStack {
            // Inner ZStack(alignment: .bottom) anchors the MiniPlayer
            // bar above the tab bar. Hidden when the full-screen Player
            // is presented (the modal is the canonical surface then).
            ZStack(alignment: .bottom) {
            TabView(selection: $nav.selectedTab) {
                // MAP — the front door of the app. Tag 0.
                // Immersive Canvas tabs (Map tree, Field constellation, Lab
                // instrument, Oracle void) pin `void` — they render glow-on-
                // void art that stays dark in Light mode by design.
                MapView()
                    .environment(\.binduTheme, ThemeData.void)
                    .tabItem {
                        Label { Text("Map") } icon: {
                            BinduTabIconImage(tab: .map, active: nav.selectedTab == 0)
                        }
                    }
                    .tag(0)
                FieldView()
                    .environment(\.binduTheme, ThemeData.void)
                    .tabItem {
                        Label { Text("Field") } icon: {
                            BinduTabIconImage(tab: .field, active: nav.selectedTab == 1)
                        }
                    }
                    .tag(1)
                // Lab sits in the primary tab bar (ahead of Oracle) — the
                // user reaches for the frequency lab far more than the
                // Oracle. Tags are unchanged (Lab stays 5, Oracle stays 2);
                // only the array *order* decides which tabs iOS shows before
                // the More overflow. Primary 4: Map · Field · Lab · AKASH.
                LabView()
                    .environment(\.binduTheme, ThemeData.void)
                    .tabItem {
                        Label { Text("Lab") } icon: {
                            BinduTabIconImage(tab: .lab, active: nav.selectedTab == 5)
                        }
                    }
                    .tag(5)
                SpaceView()
                    .tabItem {
                        Label { Text("AKASH") } icon: {
                            BinduTabIconImage(tab: .space, active: nav.selectedTab == 3)
                        }
                    }
                    .tag(3)
                ArchiveView()
                    .tabItem {
                        Label { Text("Archive") } icon: {
                            BinduTabIconImage(tab: .archive, active: nav.selectedTab == 4)
                        }
                    }
                    .tag(4)
                // Oracle is now in the More overflow. The Field central-Bindu
                // long-press still selects it (tag 2) — via a NavigationStack
                // push through More.
                OracleView()
                    .environment(\.binduTheme, ThemeData.void)
                    .tabItem {
                        Label { Text("Oracle") } icon: {
                            BinduTabIconImage(tab: .oracle, active: nav.selectedTab == 2)
                        }
                    }
                    .tag(2)
                RitualView()
                    .tabItem {
                        Label { Text("Ritual") } icon: {
                            BinduTabIconImage(tab: .ritual, active: nav.selectedTab == 6)
                        }
                    }
                    .tag(6)
                LetterView()
                    .tabItem {
                        Label { Text("Letter") } icon: {
                            BinduTabIconImage(tab: .letter, active: nav.selectedTab == 7)
                        }
                    }
                    .tag(7)
            }
            .tint(theme.accent)
            .fullScreenCover(isPresented: $store.isPresentingPlayer) {
                if let track = store.currentTrack {
                    // The Player is a fully immersive glow-on-void scene —
                    // pin `void` so it stays dark in Light mode.
                    PlayerView(track: track)
                        .environment(\.binduTheme, ThemeData.void)
                }
            }

                // MiniPlayer floats 49pt up from the bottom so it sits
                // above the tab bar's content area. It self-hides when
                // there's no current track or when the modal is up.
                VStack(spacing: 0) {
                    MiniPlayerView()
                    Spacer().frame(height: 49)
                }
                .allowsHitTesting(!store.isPresentingPlayer)
            }

            // Headphones tip — shown after birth sequence, only on first launch
            if showHeadphonesTip && !showBirthSequence {
                VStack {
                    Spacer()
                    HeadphonesTipView {
                        UserDefaults.standard.set(true, forKey: "binduFirstLaunch.tipSeen")
                        withAnimation(.easeOut(duration: 0.4)) {
                            showHeadphonesTip = false
                        }
                    }
                    .padding(.bottom, 100)  // above tab bar
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // O20: audio engine / session failures are no longer silent —
            // surface a banner the user can dismiss. The coordinator
            // clears `lastError` on the next successful transition, so
            // the banner self-heals.
            if let error = session.lastError, !showBirthSequence {
                VStack {
                    AudioErrorBanner(message: error.localizedDescription)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(50)
            }

            // First-launch Bindu birth sequence — on top of everything
            if showBirthSequence {
                BinduBirthView(onComplete: {
                    UserDefaults.standard.set(true, forKey: "binduFirstLaunch.seen")
                    withAnimation(.easeOut(duration: 0.4)) {
                        showBirthSequence = false
                    }
                })
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showBirthSequence)
        .animation(.easeInOut(duration: 0.4), value: showHeadphonesTip)
        // App-wide theme + appearance from the user's setting. Immersive
        // tabs / covers re-pin `void` above so they stay dark in Light mode.
        .environment(\.binduTheme, theme)
        .preferredColorScheme(settings.preferredColorScheme)
    }
}

/// O20: terse error banner surfaced when `AudioSessionCoordinator.lastError`
/// becomes non-nil. Foreground/background of the engine error reads as
/// "audio is broken" to a user — saying so is better than silence.
/// Tap to dismiss — without this the banner is sticky until a successful
/// session transition self-clears it, which may never happen.
private struct AudioErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(Color.orange)
            Text(message)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundColor(ThemeData.void.text)
                .lineLimit(2)
            Spacer().frame(width: 4)
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(ThemeData.void.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.92))
                .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
        )
        .padding(.horizontal, 32)
        .contentShape(Capsule())
        .onTapGesture { AudioSessionCoordinator.shared.clearError() }
    }
}

struct HeadphonesTipView: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(ThemeData.void.text)
            Text("Use headphones. Binaural needs stereo separation.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundColor(ThemeData.void.text)
            Spacer().frame(width: 4)
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(ThemeData.void.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.92))
                .overlay(Capsule().stroke(ThemeData.void.muted.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 32)
        .onTapGesture { onDismiss() }
    }
}
