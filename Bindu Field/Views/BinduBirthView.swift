import SwiftUI

struct BinduBirthView: View {
    let onComplete: () -> Void

    @State private var phase: Phase = .dark
    @State private var binduScale: CGFloat = 0
    @State private var binduOpacity: Double = 0
    @State private var blackOpacity: Double = 1

    private let theme = ThemeData.void
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

    private func runBirthSequence() {
        // Phase 1: dark (0.5s) — just sit in blackness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .emerging
            withAnimation(.easeOut(duration: 0.7)) {
                binduScale = 1.0
                binduOpacity = 1.0
            }
        }

        // Phase 2: pulse (1.2s) — Bindu breathes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            phase = .pulsing
            withAnimation(.easeInOut(duration: 0.6)) {
                binduScale = 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    binduScale = 1.0
                }
            }
        }

        // Phase 3: dissolve (0.8s) — black fades out revealing the Field beneath
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            phase = .dissolving
            withAnimation(.easeInOut(duration: 0.8)) {
                blackOpacity = 0
                binduOpacity = 0
            }
        }

        // Phase 4: complete (signal parent to remove)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            phase = .complete
            onComplete()
        }
    }
}
