import SwiftUI

struct RootView: View {
    @State private var nav = NavigationStore.shared
    @State private var store = PlayerStore.shared
    @State private var session = AudioSessionCoordinator.shared
    @State private var showBirthSequence: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.seen")
    @State private var showHeadphonesTip: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.tipSeen")

    var body: some View {
        ZStack {
            TabView(selection: $nav.selectedTab) {
                FieldView()
                    .tabItem {
                        Label { Text("Field") } icon: {
                            BinduTabIcon(tab: .field, active: nav.selectedTab == 0)
                        }
                    }
                    .tag(0)
                OracleView()
                    .tabItem {
                        Label { Text("Oracle") } icon: {
                            BinduTabIcon(tab: .oracle, active: nav.selectedTab == 1)
                        }
                    }
                    .tag(1)
                SpaceView()
                    .tabItem {
                        Label { Text("Space") } icon: {
                            BinduTabIcon(tab: .space, active: nav.selectedTab == 2)
                        }
                    }
                    .tag(2)
                LabView()
                    .tabItem {
                        Label { Text("Lab") } icon: {
                            BinduTabIcon(tab: .lab, active: nav.selectedTab == 3)
                        }
                    }
                    .tag(3)
                ArchiveView()
                    .tabItem {
                        Label { Text("Archive") } icon: {
                            BinduTabIcon(tab: .archive, active: nav.selectedTab == 4)
                        }
                    }
                    .tag(4)
                RitualView()
                    .tabItem {
                        Label { Text("Ritual") } icon: {
                            BinduTabIcon(tab: .ritual, active: nav.selectedTab == 5)
                        }
                    }
                    .tag(5)
                LetterView()
                    .tabItem {
                        Label { Text("Letter") } icon: {
                            BinduTabIcon(tab: .letter, active: nav.selectedTab == 6)
                        }
                    }
                    .tag(6)
                // MAP tab — placeholder for Session B. Tag 7 keeps existing
                // tags untouched so the Field → Oracle deep-link and other
                // tag-7-aware code paths stay correct.
                EmptyView()
                    .tabItem {
                        Label { Text("Map") } icon: {
                            BinduTabIcon(tab: .map, active: nav.selectedTab == 7)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.92))
                .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
        )
        .padding(.horizontal, 32)
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
