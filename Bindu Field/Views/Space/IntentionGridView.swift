import SwiftUI

/// Akash front door — replaces the old chakra grid. Eight tiles in a 2×4
/// grid, one per `BreathIntention`. Multi-session intentions show a small
/// "2 sessions" label so the user knows tapping leads to a chooser.
///
/// Loads breath sessions from Airtable via `BreathSessionStore` on
/// appear. Cache-aware: re-renders as soon as the cache is populated.
struct IntentionGridView: View {
    let onSelect: (BreathIntention) -> Void

    @State private var store = BreathSessionStore.shared
    @Environment(\.binduTheme) private var theme

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 4)

                offlineBanner
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        ForEach(BreathIntention.allCases, id: \.self) { intention in
                            tile(for: intention)
                                .onTapGesture { onSelect(intention) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .task {
            await store.refresh()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                Circle()
                    .fill(theme.text.opacity(0.40))
                    .frame(width: 5, height: 5)
                    .modifier(BreathPulse())
                Text("Akash")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
            }
            Text("breathe with the field")
                .font(.system(size: 8.5, weight: .light, design: .monospaced))
                .tracking(2.2)
                .foregroundColor(theme.subtle)
                .padding(.leading, 14)
        }
    }

    @ViewBuilder
    private var offlineBanner: some View {
        if store.isStaleFromCache {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 10))
                    .foregroundColor(theme.subtle)
                Text("Showing cached sessions")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
            }
        } else if store.sessions.isEmpty && store.isLoading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.mini).tint(theme.muted)
                Text("loading sessions…")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
            }
        } else if store.sessions.isEmpty, let err = store.loadError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(theme.muted)
                Text(err)
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundColor(theme.muted)
                    .lineLimit(2)
                Spacer()
                Button("retry") {
                    Task { await store.refresh(force: true) }
                }
                .font(.system(size: 10, weight: .light))
                .foregroundColor(theme.text)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func tile(for intention: BreathIntention) -> some View {
        let hue = intention.hue
        let multi = intention.sessionIDs.count > 1
        let available = !intention.sessionIDs.contains { store.session(id: $0) == nil }
            || !store.sessions.isEmpty
        let dotColor = Color(hue: hue / 360, saturation: 0.58, brightness: 0.60)
        let dotGlow = Color(hue: hue / 360, saturation: 0.55, brightness: 0.55)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: dotGlow.opacity(0.40), radius: 6)
                if multi {
                    Text("\(intention.sessionIDs.count) sessions")
                        .font(.system(size: 7, weight: .light, design: .monospaced))
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hue: hue / 360, saturation: 0.45, brightness: 0.60).opacity(0.65))
                }
                Spacer()
            }
            .padding(.bottom, 8)

            Text(intention.word)
                .font(.system(size: 19, weight: .light, design: .serif))
                .italic()
                .foregroundColor(theme.text)
                .padding(.bottom, 8)

            Spacer(minLength: 0)

            Text(intention.phrase.uppercased())
                .font(.system(size: 7.5, weight: .light, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(Color(hue: hue / 360, saturation: 0.35, brightness: 0.62).opacity(0.65))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hue: hue / 360, saturation: 0.32, brightness: 0.07).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hue: hue / 360, saturation: 0.30, brightness: 0.24).opacity(0.45), lineWidth: 1)
                )
        )
        .opacity(available ? 1.0 : 0.55)
    }
}

/// Breath modulator for the small header dot.
private struct BreathPulse: ViewModifier {
    @State private var brighter = false
    func body(content: Content) -> some View {
        content
            .opacity(brighter ? 1.0 : 0.55)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    brighter = true
                }
            }
    }
}
