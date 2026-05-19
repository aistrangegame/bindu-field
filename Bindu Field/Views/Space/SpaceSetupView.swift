import SwiftUI

extension ChakraProtocol {
    /// Display color derived from the chakra's hue (degrees, 0–360).
    var color: Color {
        Color(hue: hue / 360.0, saturation: 0.55, brightness: 0.92)
    }
}

/// Canonical ordering of chakras for grid display: root → maya.
let chakraOrder: [ChakraName] = [
    .muladhara, .svadhisthana, .manipura,
    .anahata, .vishuddha, .ajna,
    .sahasrara, .aatma, .maya,
]

let orderedChakras: [ChakraProtocol] = chakraOrder.compactMap { ChakraData.all[$0] }

struct SpaceSetupView: View {
    let onBegin: (ChakraProtocol, Int) -> Void  // chakra, durationMinutes

    @State private var selectedChakra: ChakraName = .anahata

    /// G6: initial duration follows `SettingsStore.defaultSessionDuration`.
    /// Clamp to the available chip values (3 / 5 / 10 / 15) so we always
    /// have a selected chip; fall back to 5 if the configured default
    /// doesn't land on one of them.
    @State private var durationMinutes: Int = {
        let chips = [3, 5, 10, 15]
        let configured = Int(SettingsStore.shared.defaultSessionDuration / 60)
        return chips.contains(configured) ? configured : 5
    }()

    @Environment(\.binduTheme) private var theme

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Empty Space")
                            .font(.system(size: 32, weight: .ultraLight, design: .serif))
                            .italic()
                            .foregroundColor(theme.text)
                        Text("breathe with the field")
                            .font(.system(size: 14))
                            .foregroundColor(theme.muted)
                    }
                    .padding(.top, 40)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(orderedChakras, id: \.name) { chakra in
                            ChakraTile(chakra: chakra, isSelected: selectedChakra == chakra.name)
                                .onTapGesture { selectedChakra = chakra.name }
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        Text("duration")
                            .font(.system(size: 10, weight: .light))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(theme.subtle)

                        HStack(spacing: 12) {
                            ForEach([3, 5, 10, 15], id: \.self) { mins in
                                Button(action: { durationMinutes = mins }) {
                                    Text("\(mins) min")
                                        .font(.system(size: 13))
                                        .foregroundColor(durationMinutes == mins ? theme.text : theme.muted)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(durationMinutes == mins ? theme.accent.opacity(0.2) : Color.clear)
                                                .overlay(Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1))
                                        )
                                }
                            }
                        }
                    }

                    Button(action: {
                        if let chakra = ChakraData.all[selectedChakra] {
                            onBegin(chakra, durationMinutes)
                        }
                    }) {
                        Text("Begin")
                            .font(.system(size: 18, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(theme.bg)
                            .padding(.horizontal, 60)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(theme.text))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

private struct ChakraTile: View {
    let chakra: ChakraProtocol
    let isSelected: Bool
    @Environment(\.binduTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(chakra.color)
                .frame(width: 36, height: 36)
                .shadow(color: isSelected ? chakra.color.opacity(0.8) : .clear, radius: 12)
            Text(chakra.name.rawValue)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundColor(theme.text)
            Text(chakra.center)
                .font(.system(size: 9))
                .foregroundColor(theme.subtle)
                .textCase(.uppercase)
                .tracking(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? chakra.color.opacity(0.1) : theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? chakra.color.opacity(0.6) : theme.muted.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
