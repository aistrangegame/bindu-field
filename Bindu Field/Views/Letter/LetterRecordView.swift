import SwiftUI
import UIKit

struct LetterRecordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .setup
    @State private var stateSelection: StateOption = .alpha
    @State private var recordedURL: URL?
    @State private var recordedDuration: Double = 0
    @State private var elapsed: Double = 0
    @State private var savedTitle: String = ""
    @State private var countdownNum: Int = 3
    @State private var permissionDenied = false
    @State private var meterLevel: Float = 0

    /// True after the user explicitly saves the letter. Used by .onDisappear
    /// to distinguish "user finished" from "user swiped away in review",
    /// the latter being a leak that has to clean up the orphan m4a (B14).
    @State private var didSave: Bool = false

    private let theme = ThemeData.void

    enum Phase {
        case setup, countdown, recording, review
    }

    enum StateOption: String, CaseIterable {
        case delta, theta, alpha, silent
        var carrier: Float { 136.0 }
        var beat: Float {
            switch self {
            case .delta:  return 2.5
            case .theta:  return 5.5
            case .alpha:  return 10.0
            case .silent: return 0
            }
        }
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            Group {
                switch phase {
                case .setup:     setupView
                case .countdown: countdownView
                case .recording: recordingView
                case .review:    reviewView
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(phase == .recording || phase == .countdown)
        .alert("Microphone access denied", isPresented: $permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Enable microphone access in iOS Settings → Bindu Field to record letters.")
        }
        .onDisappear {
            // B14: if the user swipes away while in the review phase, the
            // m4a in Documents/Letters/ was never linked from LetterStore.
            // Clean it up so it doesn't accumulate as an orphan.
            if !didSave, let url = recordedURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(theme.muted)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Record a Letter")
                    .font(.system(size: 28, weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Text("speak from this state")
                    .font(.system(size: 13))
                    .foregroundColor(theme.muted)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 12) {
                Text("brainwave state")
                    .font(.system(size: 10, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(theme.subtle)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StateOption.allCases, id: \.self) { option in
                            Button(action: { stateSelection = option }) {
                                Text(option.rawValue)
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(stateSelection == option ? theme.bg : theme.muted)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(stateSelection == option ? theme.text : Color.clear)
                                            .overlay(Capsule().stroke(theme.muted.opacity(0.3), lineWidth: stateSelection == option ? 0 : 1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Text("The selected binaural plays softly while you speak. Use headphones to keep it out of the recording.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.subtle)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 36)

            Spacer()

            Button(action: { Task { await beginCountdown() } }) {
                Text("Begin")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.bg)
                    .padding(.horizontal, 56)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(theme.text))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(countdownNum)")
                .font(.system(size: 96, weight: .ultraLight, design: .serif))
                .italic()
                .foregroundColor(theme.text)
                .id(countdownNum)
                .transition(.opacity)
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: countdownNum)
    }

    private var recordingView: some View {
        ZStack {
            RadialGradient(
                colors: [Color.red.opacity(0.18 + CGFloat(meterLevel) * 0.15), theme.bg],
                center: .center,
                startRadius: 80,
                endRadius: 700
            )
            .ignoresSafeArea()
            .animation(.linear(duration: 0.1), value: meterLevel)

            VStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.25))
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.0 + CGFloat(meterLevel) * 0.5)
                        .animation(.linear(duration: 0.08), value: meterLevel)
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 64, height: 64)
                }

                Text(formatTime(elapsed))
                    .font(.system(size: 32, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(theme.text)
                    .padding(.top, 32)

                Text("recording")
                    .font(.system(size: 11))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(theme.subtle)
                    .padding(.top, 4)

                Spacer()

                Button(action: stopRecording) {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                        Text("Stop")
                            .font(.system(size: 16, design: .serif))
                            .italic()
                    }
                    .foregroundColor(theme.bg)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(theme.text))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }

    private var reviewView: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Cancel") { discardLetter() }
                    .foregroundColor(theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Letter recorded")
                    .font(.system(size: 22, weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Text("\(stateSelection.rawValue) · \(formatTime(recordedDuration))")
                    .font(.system(size: 12))
                    .foregroundColor(theme.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("title")
                    .font(.system(size: 10, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(theme.subtle)
                TextField("A letter", text: $savedTitle)
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.muted.opacity(0.2), lineWidth: 1))
                    )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: saveLetter) {
                Text("Save")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(theme.bg)
                    .padding(.horizontal, 56)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(theme.text))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func beginCountdown() async {
        let granted = await RecorderService.shared.requestPermission()
        if !granted {
            permissionDenied = true
            return
        }

        phase = .countdown
        for n in stride(from: 3, through: 1, by: -1) {
            countdownNum = n
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if phase != .countdown { return }
        }
        startRecording()
    }

    private func startRecording() {
        do {
            recordedURL = try RecorderService.shared.start()
        } catch {
            print("Recording start failed: \(error)")
            phase = .setup
            return
        }

        if stateSelection != .silent {
            PlayerStore.shared.startBinaural(carrier: stateSelection.carrier, beat: stateSelection.beat)
            PlayerStore.shared.setGain(SettingsStore.shared.gain)
        }

        phase = .recording
        elapsed = 0

        Task {
            while phase == .recording {
                try? await Task.sleep(nanoseconds: 100_000_000)
                elapsed += 0.1
                meterLevel = RecorderService.shared.peakLevel()
            }
        }
    }

    private func stopRecording() {
        let duration = RecorderService.shared.stop()
        if stateSelection != .silent {
            PlayerStore.shared.stopBinaural()
        }
        recordedDuration = duration

        let df = DateFormatter()
        df.dateFormat = "MMM d · h:mm a"
        savedTitle = "Letter · \(df.string(from: Date()))"

        phase = .review
    }

    private func saveLetter() {
        guard let url = recordedURL else { dismiss(); return }
        let letter = Letter(
            id: UUID(),
            title: savedTitle.isEmpty ? "A letter" : savedTitle,
            timestamp: Date(),
            filename: url.lastPathComponent,
            durationSec: recordedDuration,
            stateLabel: stateSelection.rawValue,
            carrier: stateSelection.carrier,
            beat: stateSelection.beat
        )
        LetterStore.shared.save(letter)
        didSave = true
        dismiss()
    }

    private func discardLetter() {
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        dismiss()
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
