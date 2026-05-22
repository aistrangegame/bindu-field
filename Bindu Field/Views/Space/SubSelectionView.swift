import SwiftUI

/// Sub-selection — surfaces when an intention holds more than one
/// session (today: `.open` → 103 + 110, `.rest` → 106 + 111, `.balance`
/// → 102 + 109). Lists the candidate sessions with one-line + state +
/// carrier badge.
struct SubSelectionView: View {
    let intention: BreathIntention
    let onSelect: (JoinedBreathSession) -> Void
    let onBack: () -> Void

    @State private var store = BreathSessionStore.shared
    @Environment(\.binduTheme) private var theme

    private var hue: Double { intention.hue }
    private var accent: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.65)
    }

    private var sessions: [JoinedBreathSession] {
        intention.sessionIDs.compactMap { id in
            store.session(id: id).map { $0.joined() }
        }
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: onBack) {
                        Text("← \(intention.word.uppercased())")
                            .font(.system(size: 9, weight: .light, design: .monospaced))
                            .tracking(1.8)
                            .foregroundColor(theme.subtle)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 18)

                    Text("choose your session")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("two paths into the same opening")
                        .font(.system(size: 8.5, weight: .light, design: .monospaced))
                        .tracking(1.8)
                        .foregroundColor(theme.subtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(sessions) { session in
                            tile(for: session)
                                .onTapGesture { onSelect(session) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(for session: JoinedBreathSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.name)
                .font(.system(size: 20, weight: .light, design: .serif))
                .italic()
                .foregroundColor(theme.text)
            Text(session.oneLine)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(session.stateInfo.key.lowercased())
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundColor(Color(hue: hue / 360, saturation: 0.45, brightness: 0.62))
                Text("·")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(theme.subtle.opacity(0.4))
                Text(String(format: "%.1f Hz carrier", session.carrierHz))
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.subtle)
                if session.safety == .screened {
                    Spacer(minLength: 8)
                    screenedBadge
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hue: hue / 360, saturation: 0.32, brightness: 0.07).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hue: hue / 360, saturation: 0.30, brightness: 0.24).opacity(0.45), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var screenedBadge: some View {
        Text("SCREENED")
            .font(.system(size: 7, weight: .regular, design: .monospaced))
            .tracking(1.6)
            .foregroundColor(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.35), lineWidth: 0.5)
                    )
            )
    }
}
