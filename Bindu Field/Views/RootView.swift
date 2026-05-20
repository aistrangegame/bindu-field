import SwiftUI

struct RootView: View {
    @State private var nav = NavigationStore.shared
    @State private var store = PlayerStore.shared
    @State private var session = AudioSessionCoordinator.shared
    @State private var showBirthSequence: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.seen")
    @State private var showHeadphonesTip: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.tipSeen")

    var body: some View {
        ZStack {
            // Inner ZStack(alignment: .bottom) anchors the MiniPlayer
            // bar above the tab bar. Hidden when the full-screen Player
            // is presented (the modal is the canonical surface then).
            ZStack(alignment: .bottom) {
            TabView(selection: $nav.selectedTab) {
                // MAP — the front door of the app. Tag 0.
                MapView()
                    .tabItem {
                        Label { Text("Map") } icon: {
                            BinduTabIconImage(tab: .map, active: nav.selectedTab == 0)
                        }
                    }
                    .tag(0)
                FieldView()
                    .tabItem {
                        Label { Text("Field") } icon: {
                            BinduTabIconImage(tab: .field, active: nav.selectedTab == 1)
                        }
                    }
                    .tag(1)
                OracleView()
                    .tabItem {
                        Label { Text("Oracle") } icon: {
                            BinduTabIconImage(tab: .oracle, active: nav.selectedTab == 2)
                        }
                    }
                    .tag(2)
                // Primary 5 finishes here: Space (renamed AKASH in the
                // tabItem label) → Archive. iOS auto-collapses tabs 5–7
                // into the More menu.
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
                LabView()
                    .tabItem {
                        Label { Text("Lab") } icon: {
                            BinduTabIconImage(tab: .lab, active: nav.selectedTab == 5)
                        }
                    }
                    .tag(5)
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
            .preferredColorScheme(.dark)
            .tint(ThemeData.void.accent)
            .fullScreenCover(isPresented: $store.isPresentingPlayer) {
                if let track = store.currentTrack {
                    PlayerView(track: track)
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
