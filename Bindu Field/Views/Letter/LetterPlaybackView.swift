import SwiftUI
import AVFoundation

struct LetterPlaybackView: View {
    let letter: Letter
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var elapsed: Double = 0

    private let theme = ThemeData.void

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Done") {
                        stopAll()
                        dismiss()
                    }
                    .foregroundColor(theme.muted)
                    Spacer()
                    ShareLink(
                        item: letter.audioURL,
                        subject: Text(letter.title),
                        message: Text("A Letter, recorded in \(letter.stateLabel) state. Carrier \(Int(letter.carrier)) Hz, beat \(String(format: "%.1f", letter.beat)) Hz. — Bindu Field")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(theme.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    Text(letter.title)
                        .font(.system(size: 26, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Text("\(letter.stateLabel) · \(Int(letter.carrier)) Hz · \(String(format: "%.1f", letter.beat)) Hz")
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
                }

                Spacer()

                VStack(spacing: 12) {
                    ProgressView(value: elapsed, total: max(letter.durationSec, 0.1))
                        .tint(theme.accent)
                        .padding(.horizontal, 60)
                    Text("\(formatTime(elapsed)) / \(formatTime(letter.durationSec))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.muted)
                }

                Button(action: togglePlay) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(isPlaying ? 0.3 : 0.15))
                            .frame(width: 96, height: 96)
                        Circle()
                            .stroke(theme.accent, lineWidth: 1)
                            .frame(width: 96, height: 96)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(theme.text)
                            .offset(x: isPlaying ? 0 : 3)
                    }
                }
                .padding(.top, 32)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { stopAll() }
    }

    private func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func play() {
        if player == nil {
            do {
                player = try AVAudioPlayer(contentsOf: letter.audioURL)
                player?.prepareToPlay()
            } catch {
                print("Failed to load letter: \(error)")
                return
            }
        }

        if letter.beat > 0 {
            PlayerStore.shared.startBinaural(carrier: letter.carrier, beat: letter.beat)
            PlayerStore.shared.setGain(SettingsStore.shared.gain)
        }

        player?.play()
        isPlaying = true

        Task {
            while isPlaying, let p = player, p.isPlaying {
                try? await Task.sleep(nanoseconds: 100_000_000)
                elapsed = p.currentTime
            }
            if let p = player, !p.isPlaying, isPlaying {
                stopAll()
            }
        }
    }

    private func pause() {
        player?.pause()
        if letter.beat > 0 {
            PlayerStore.shared.stopBinaural()
        }
        isPlaying = false
    }

    private func stopAll() {
        player?.stop()
        player = nil
        if letter.beat > 0 {
            PlayerStore.shared.stopBinaural()
        }
        isPlaying = false
        elapsed = 0
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
