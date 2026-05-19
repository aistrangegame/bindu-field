import SwiftUI

struct RootView: View {
    @State private var nav = NavigationStore.shared
    @State private var store = PlayerStore.shared
    @State private var showBirthSequence: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.seen")
    @State private var showHeadphonesTip: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.tipSeen")

    var body: some View {
        ZStack {
            TabView(selection: $nav.selectedTab) {
                FieldView()
                    .tabItem { Label("Field", systemImage: "circle.dotted") }
                    .tag(0)
                OracleView()
                    .tabItem { Label("Oracle", systemImage: "ear") }
                    .tag(1)
                SpaceView()
                    .tabItem { Label("Space", systemImage: "moon.stars") }
                    .tag(2)
                LabView()
                    .tabItem { Label("Lab", systemImage: "waveform.path") }
                    .tag(3)
                ArchiveView()
                    .tabItem { Label("Archive", systemImage: "book.closed") }
                    .tag(4)
                RitualView()
                    .tabItem { Label("Ritual", systemImage: "flame") }
                    .tag(5)
                LetterView()
                    .tabItem { Label("Letter", systemImage: "envelope") }
                    .tag(6)
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
