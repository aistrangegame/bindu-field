import SwiftUI

extension View {
    /// Two-layer element-color glow. The design's verb / button shadows
    /// are never a single shadow — they're a tight inner halo + a wider,
    /// fainter ambient bloom. Calling `.shadow` twice in a row stacks them
    /// without one cancelling the other.
    func binduGlow(color: Color,
                   tight: CGFloat = 0.22,
                   wide: CGFloat = 0.08) -> some View {
        self
            .shadow(color: color.opacity(Double(tight)), radius: 14)
            .shadow(color: color.opacity(Double(wide)), radius: 40)
    }
}
