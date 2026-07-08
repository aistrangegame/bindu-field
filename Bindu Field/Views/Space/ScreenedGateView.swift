import SwiftUI

/// Warm, non-clinical contraindication check shown before screened-tier
/// sessions (today: 105 The Stoke). Phrased as a self-check rather than a
/// medical form. Soft guidance appears when any condition is checked,
/// suggesting a gentler alternative; the user can always proceed.
struct ScreenedGateView: View {
    let session: JoinedBreathSession
    let onProceed: () -> Void
    let onChooseOther: () -> Void

    @State private var acknowledged: Set<Int> = []
    @Environment(\.binduTheme) private var theme

    private var hue: Double { session.hue }
    private var accent: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.65)
    }

    private let conditions: [String] = [
        "Heart condition or irregular heartbeat",
        "Currently pregnant",
        "History of epilepsy or seizure",
        "High blood pressure (unmanaged)",
    ]

    private var anySelected: Bool { !acknowledged.isEmpty }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(hue: hue / 360, saturation: 0.40, brightness: 0.12).opacity(0.35),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.30),
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title block
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(session.name) · Activation".uppercased())
                                .font(.system(size: 8.5, weight: .light, design: .monospaced))
                                .tracking(2.2)
                                .foregroundColor(Color(hue: hue / 360, saturation: 0.45, brightness: 0.60).opacity(0.65))
                            Text("A strong practice.")
                                .font(.system(size: 24, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(theme.text)
                                .lineSpacing(2)
                            Text("Before you begin, a moment. This session moves energy rapidly — it asks something of the body. Do any of these speak to where you are today?")
                                .font(.system(size: 14, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted)
                                .lineSpacing(5)
                        }
                        .padding(.bottom, 26)

                        // Conditions
                        VStack(spacing: 10) {
                            ForEach(conditions.indices, id: \.self) { i in
                                conditionRow(i)
                            }
                        }
                        .padding(.bottom, 24)

                        // Guidance card if anything selected
                        if anySelected {
                            HStack(spacing: 0) {
                                Text(suggestedAlternativeText())
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.muted)
                                    .lineSpacing(4)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hue: hue / 360, saturation: 0.22, brightness: 0.08).opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hue: hue / 360, saturation: 0.28, brightness: 0.22).opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.bottom, 18)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 36)
                }

                // CTAs
                VStack(spacing: 10) {
                    Button(action: onProceed) {
                        Text(anySelected ? "proceed with awareness" : "Begin")
                            .font(.system(size: 15, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(theme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(theme.text))
                    }
                    .buttonStyle(.plain)
                    Button(action: onChooseOther) {
                        Text("choose another session")
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule().stroke(theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .animation(.easeInOut(duration: 0.25), value: anySelected)
            }
        }
    }

    @ViewBuilder
    private func conditionRow(_ i: Int) -> some View {
        let isOn = acknowledged.contains(i)
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOn { acknowledged.remove(i) } else { acknowledged.insert(i) }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isOn ? accent : theme.text.opacity(0.2), lineWidth: 1)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(isOn ? Color(hue: hue / 360, saturation: 0.38, brightness: 0.18).opacity(0.8) : Color.clear)
                        )
                    if isOn {
                        Circle().fill(accent).frame(width: 8, height: 8)
                    }
                }
                Text(conditions[i])
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(isOn ? theme.muted : theme.subtle)
                    .lineSpacing(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn
                          ? Color(hue: hue / 360, saturation: 0.30, brightness: 0.12).opacity(0.7)
                          : theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isOn ? Color(hue: hue / 360, saturation: 0.35, brightness: 0.32).opacity(0.55)
                                         : theme.border,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Gentle suggestion text. Names a soft alternative — for The Stoke
    /// (105) that's "The Long Release" (106) which holds similar opening
    /// at a much softer pace.
    private func suggestedAlternativeText() -> String {
        switch session.id {
        case 105:
            return "You can still enter — with awareness. If you'd prefer a gentler practice, The Long Release holds similar opening at a much softer pace."
        default:
            return "You can still enter — with awareness. A gentler practice may be a better fit today."
        }
    }
}
