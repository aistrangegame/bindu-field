import SwiftUI

/// Bottom sheet raised by tapping a node on the Map. State drives the CTA:
/// `available` → ENTER THIS DANCE; `danced` → DANCE AGAIN; `locked` →
/// "this dance has not yet been composed" (no button).
struct MapDetailSheet: View {
    let chakra: ChakraNode
    let state: ChakraNodeState
    let track: Track?
    let onEnter: (Track) -> Void

    @Environment(\.dismiss) private var dismiss

    private var elementColor: Color {
        Color(hue: chakra.hue / 360, saturation: 0.55, brightness: 0.68)
    }
    private var elementSoft: Color {
        Color(hue: chakra.hue / 360, saturation: 0.50, brightness: 0.60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 34, height: 3)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 18)

            // System + state badges
            HStack {
                Text(chakra.system.rawValue.uppercased())
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.40))
                Spacer()
                Text(stateLabel)
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(stateBadgeColor)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)

            // Name + Sanskrit
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(chakra.name)
                    .font(.system(size: 28, weight: .light, design: .serif).italic())
                    .foregroundStyle(elementColor)
                Text(chakra.skt)
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .foregroundStyle(elementColor.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // Hairline divider
            Rectangle()
                .fill(elementColor.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // Essence
            Text(chakra.essence)
                .font(.system(size: 15, weight: .light, design: .serif).italic())
                .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.55))
                .lineSpacing(6)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            Spacer(minLength: 0)

            // CTA
            HStack {
                Spacer()
                cta
                Spacer()
            }
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(elementColor.opacity(0.25))
                .frame(height: 1)
        }
    }

    private var stateLabel: String {
        switch state {
        case .danced:    return "DANCED"
        case .available: return "AVAILABLE"
        case .locked:    return "LOCKED"
        }
    }

    private var stateBadgeColor: Color {
        switch state {
        case .danced:    return elementSoft.opacity(0.75)
        case .available: return Color(hex: "#F5E2D6").opacity(0.45)
        case .locked:    return Color(hex: "#F5E2D6").opacity(0.25)
        }
    }

    @ViewBuilder
    private var cta: some View {
        switch state {
        case .available:
            if let track {
                Button(action: { onEnter(track) }) {
                    Text("ENTER THIS DANCE")
                        .font(.system(size: 9, weight: .light))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(elementColor)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .overlay(Capsule().stroke(elementSoft.opacity(0.30), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                lockedCopy
            }
        case .danced:
            if let track {
                Button(action: { onEnter(track) }) {
                    Text("DANCE AGAIN")
                        .font(.system(size: 9, weight: .light))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(elementColor)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .overlay(Capsule().stroke(elementSoft.opacity(0.30), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                lockedCopy
            }
        case .locked:
            lockedCopy
        }
    }

    private var lockedCopy: some View {
        Text("this dance has not yet been composed")
            .font(.system(size: 11, weight: .light, design: .serif).italic())
            .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.32))
            .multilineTextAlignment(.center)
    }
}
