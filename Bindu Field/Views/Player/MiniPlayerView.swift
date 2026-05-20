import SwiftUI

/// Compact playback bar that surfaces above the tab bar when a track is
/// playing but the full-screen PlayerView is not presented. Element-dot
/// + verb / song + play-pause + tap-to-restore-Player. Hidden when no
/// track is loaded or while the Player modal is up (the modal is the
/// canonical surface in that case).
struct MiniPlayerView: View {
    @State private var store = PlayerStore.shared
    @State private var service = TrackPlaybackService.shared
    @Environment(\.binduTheme) private var theme

    var body: some View {
        // Show only when there's a track and the modal Player isn't up.
        // Both isPlaying and isPaused count as "loaded" — paused-with-
        // queued-position is still a session the user can rejoin.
        if !store.isPresentingPlayer,
           let track = store.currentTrack,
           service.isPlaying || service.isPaused {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.bindu(element: track.element))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.bindu(element: track.element).opacity(0.5), radius: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.verb)
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(Color.bindu(element: track.element))
                        .lineLimit(1)
                    Text(track.song)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    service.togglePlayPause()
                } label: {
                    Image(systemName: service.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(theme.text.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color(red: 5/255, green: 5/255, blue: 16/255).opacity(0.95)
                    Rectangle().fill(.ultraThinMaterial).opacity(0.30)
                }
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap anywhere outside the play/pause hit area reopens
                // the full Player. The button absorbs taps on the icon
                // via its own contentShape so a play/pause tap doesn't
                // also raise the modal.
                store.isPresentingPlayer = true
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
