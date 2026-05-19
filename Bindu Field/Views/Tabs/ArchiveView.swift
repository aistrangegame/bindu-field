import SwiftUI

struct ArchiveView: View {
    @State private var store = SessionStore.shared
    @State private var showingSettings = false
    private let theme = ThemeData.void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()

                if store.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(ThemeData.void.muted)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(theme.subtle)
            Text("Your practice will\naccumulate here.")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.0) { dateString, sessions in
                Section {
                    ForEach(sessions) { session in
                        SessionRow(session: session)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(theme.muted.opacity(0.15))
                    }
                } header: {
                    Text(dateString)
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var groupedSessions: [(String, [Session])] {
        let grouped = Dictionary(grouping: store.sessions) { session in
            DateFormatter.archiveDate.string(from: session.timestamp)
        }
        return grouped.sorted { lhs, rhs in
            guard let l = lhs.value.first?.timestamp,
                  let r = rhs.value.first?.timestamp else { return false }
            return l > r
        }
    }
}

private struct SessionRow: View {
    let session: Session
    private let theme = ThemeData.void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.type == .track ? "circle.dotted" : "moon.stars")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(theme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Text(session.secondaryLabel)
                    .font(.system(size: 11))
                    .foregroundColor(theme.muted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(session.duration))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.text)
                Text(DateFormatter.archiveTime.string(from: session.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(theme.subtle)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

private extension DateFormatter {
    static let archiveDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()

    static let archiveTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
}
