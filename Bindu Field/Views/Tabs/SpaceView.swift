import SwiftUI

struct SpaceView: View {
    @State private var activeSession: ActiveSession? = nil

    struct ActiveSession {
        let chakra: ChakraProtocol
        let duration: Int
    }

    var body: some View {
        ZStack {
            if let session = activeSession {
                SpaceImmersedView(
                    chakra: session.chakra,
                    durationMinutes: session.duration,
                    onEnd: { _ in activeSession = nil }
                )
            } else {
                SpaceSetupView(onBegin: { chakra, duration in
                    activeSession = ActiveSession(chakra: chakra, duration: duration)
                })
            }
        }
    }
}
