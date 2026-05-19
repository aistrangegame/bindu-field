import SwiftUI

struct LetterView: View {
    @State private var store = LetterStore.shared
    @State private var showingRecorder = false
    @State private var playingLetter: Letter? = nil

    @Environment(\.binduTheme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()

                if store.letters.isEmpty {
                    emptyState
                } else {
                    letterList
                }
            }
            .navigationTitle("Letter")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingRecorder) {
                LetterRecordView()
            }
            .sheet(item: $playingLetter) { letter in
                LetterPlaybackView(letter: letter)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(theme.subtle)
            Text("speak from this state")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundColor(theme.muted)
            Text("Tap + to record a Sound Letter.\nYour voice, layered over the field.")
                .font(.system(size: 12))
                .foregroundColor(theme.subtle)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var letterList: some View {
        List {
            ForEach(store.letters) { letter in
                LetterRow(letter: letter)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(theme.muted.opacity(0.15))
                    .contentShape(Rectangle())
                    .onTapGesture { playingLetter = letter }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.delete(letter)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct LetterRow: View {
    let letter: Letter
    @Environment(\.binduTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(letter.title)
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Text("\(letter.stateLabel) · \(formatDuration(letter.durationSec))")
                    .font(.system(size: 11))
                    .foregroundColor(theme.muted)
            }

            Spacer()

            ShareLink(
                item: letter.audioURL,
                subject: Text(letter.title),
                message: Text("A Letter, recorded in \(letter.stateLabel) state. Carrier \(Int(letter.carrier)) Hz, beat \(String(format: "%.1f", letter.beat)) Hz. — Bindu Field")
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(theme.muted)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
