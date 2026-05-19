import SwiftUI

struct RitualView: View {
    @State private var activeRitual: [RitualStep]? = nil

    var body: some View {
        ZStack {
            if let ritual = activeRitual {
                RitualRunningView(
                    steps: ritual,
                    onEnd: { activeRitual = nil }
                )
            } else {
                RitualSetupView(onBegin: { steps in
                    activeRitual = steps
                })
            }
        }
    }
}
