import SwiftUI

struct RitualRunningView: View {
    let steps: [RitualStep]
    let onEnd: () -> Void

    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            if currentIndex < steps.count {
                let step = steps[currentIndex]
                SpaceImmersedView(
                    chakra: step.chakra,
                    durationMinutes: step.durationMinutes,
                    onEnd: { completed in
                        if completed && currentIndex + 1 < steps.count {
                            currentIndex += 1
                        } else {
                            onEnd()
                        }
                    },
                    ritualProgress: (current: currentIndex + 1, total: steps.count),
                    audioSource: .ritual
                )
                .id(currentIndex)  // force fresh state on each step transition
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: currentIndex)
    }
}
