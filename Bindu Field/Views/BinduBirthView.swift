import SwiftUI

struct BinduBirthView: View {
    let onComplete: () -> Void

    @State private var phase: Phase = .dark
    @State private var binduScale: CGFloat = 0
    @State private var binduOpacity: Double = 0
    @State private var blackOpacity: Double = 1

    @Environment(\.binduTheme) private var theme
    private let binduColor = Color(red: 0.898, green: 0.322, blue: 0.306)  // #E5524E

    enum Phase {
        case dark, emerging, pulsing, dissolving, complete
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(blackOpacity)
                .ignoresSafeArea()

            // Bindu
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [binduColor.opacity(0.5), binduColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .opacity(binduOpacity * 0.8)

                // Core dot
                Circle()
                    .fill(binduColor)
                    .frame(width: 28, height: 28)
                    .shadow(color: binduColor.opacity(0.9), radius: 12)
                    .opacity(binduOpacity)
            }
            .scaleEffect(binduScale)
        }
        .onAppear {
            runBirthSequence()
        }
    }

    /// O15: linear Task-based sequence. Easier to reason about than nested
    /// `DispatchQueue.main.asyncAfter` blocks and gives us cancellation for
    /// free if a future caller needs it.
    private func runBirthSequence() {
        Task { @MainActor in
            // Phase 1: dark (0.5s) — sit in blackness
            try? await Task.sleep(nanoseconds: 500_000_000)
            phase = .emerging
            withAnimation(.easeOut(duration: 0.7)) {
                binduScale = 1.0
                binduOpacity = 1.0
            }

            // Phase 2: pulse — Bindu breathes
            try? await Task.sleep(nanoseconds: 800_000_000)
            phase = .pulsing
            withAnimation(.easeInOut(duration: 0.6)) {
                binduScale = 1.5
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.easeInOut(duration: 0.6)) {
                binduScale = 1.0
            }

            // Phase 3: dissolve — black fades out revealing the Field beneath
            try? await Task.sleep(nanoseconds: 700_000_000)
            phase = .dissolving
            withAnimation(.easeInOut(duration: 0.8)) {
                blackOpacity = 0
                binduOpacity = 0
            }

            // Phase 4: signal parent to remove
            try? await Task.sleep(nanoseconds: 900_000_000)
            phase = .complete
            onComplete()
        }
    }
}
