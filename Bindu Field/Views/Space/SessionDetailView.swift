import SwiftUI

/// Session detail — the in-between screen between intention and immersed.
/// Shows the session name, one-line, recognition statement, breath-cycle
/// blocks, frequency line with honesty-tier badges, duration chips, and
/// the seed phrase. Begin advances to immersed (or to the screened gate
/// when `safety == .screened`).
struct SessionDetailView: View {
    let session: JoinedBreathSession
    let onBegin: (Int) -> Void          // durationMinutes
    let onBack: () -> Void
    let onReadMore: () -> Void

    @Environment(\.binduTheme) private var theme

    @State private var duration: Int = {
        let chips = [3, 5, 10, 15]
        let configured = Int(SettingsStore.shared.defaultSessionDuration / 60)
        return chips.contains(configured) ? configured : 10
    }()

    private var hue: Double { session.hue }
    private var accent: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.65)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(hue: hue / 360, saturation: 0.38, brightness: 0.10).opacity(0.18),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header — back + screened badge
                        HStack {
                            Button(action: onBack) {
                                Text("←")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(theme.subtle)
                                    .frame(width: 44, height: 44, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            if session.safety == .screened {
                                screenedBadge
                                    .padding(.trailing, 16)
                            }
                        }
                        .padding(.top, 8)

                        // Name + description
                        VStack(alignment: .leading, spacing: 12) {
                            Text(session.name)
                                .font(.system(size: 28, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(theme.text)
                            Text(session.oneLine)
                                .font(.system(size: 14.5, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)

                        // Recognition statement — a knowing whisper, hairline-rule on the left
                        if let rec = session.recognitionStatement, !rec.isEmpty {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(accent.opacity(0.3))
                                    .frame(width: 1)
                                Text("\"\(rec)\"")
                                    .font(.system(size: 13, design: .serif))
                                    .italic()
                                    .foregroundColor(Color(hue: hue / 360, saturation: 0.45, brightness: 0.72).opacity(0.78))
                                    .lineSpacing(4)
                                    .padding(.leading, 16)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                        }

                        // Breath cycle blocks
                        breathCycleSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                        // Frequency lines with honesty tiers
                        frequencySection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)

                        // Duration chips
                        durationSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)

                        // Seed phrase
                        Text("\"\(session.seed)\"")
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundColor(theme.subtle.opacity(0.55))
                            .lineSpacing(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 24)
                    }
                }

                // Sticky bottom action row
                VStack(spacing: 10) {
                    Button(action: { onBegin(duration) }) {
                        Text("Begin")
                            .font(.system(size: 16, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(theme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                Capsule().fill(theme.text)
                            )
                            .binduGlow(color: accent, tight: 0.0, wide: 0.18)
                    }
                    .buttonStyle(.plain)
                    Button(action: onReadMore) {
                        Text("read this session ↓")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(theme.subtle.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(
                    theme.bg.opacity(0.96)
                        .overlay(
                            Rectangle()
                                .fill(theme.border)
                                .frame(height: 1),
                            alignment: .top
                        )
                )
            }
        }
    }

    // MARK: - Sections

    private var phases: [(String, Int)] {
        var rows: [(String, Int)] = []
        if session.inhale > 0 { rows.append(("inhale", session.inhale)) }
        if session.hold   > 0 { rows.append(("hold",   session.hold)) }
        if session.exhale > 0 { rows.append(("exhale", session.exhale)) }
        return rows
    }

    @ViewBuilder
    private var breathCycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREATH CYCLE")
                .font(.system(size: 8, weight: .light, design: .monospaced))
                .tracking(2.2)
                .foregroundColor(theme.subtle)
            HStack(spacing: 8) {
                ForEach(phases, id: \.0) { p in
                    VStack(spacing: 4) {
                        Text("\(p.1)")
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundColor(accent)
                            .tracking(-0.4)
                        Text(p.0.uppercased())
                            .font(.system(size: 8, weight: .light, design: .monospaced))
                            .tracking(1.8)
                            .foregroundColor(theme.subtle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hue: hue / 360, saturation: 0.28, brightness: 0.08).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hue: hue / 360, saturation: 0.28, brightness: 0.22).opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }

            if let cue = session.special {
                Text(cue.cueLabel)
                    .font(.system(size: 11.5, design: .serif))
                    .italic()
                    .foregroundColor(Color(hue: hue / 360, saturation: 0.40, brightness: 0.65).opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREQUENCY")
                .font(.system(size: 8, weight: .light, design: .monospaced))
                .tracking(2.2)
                .foregroundColor(theme.subtle)
            HStack(spacing: 6) {
                Text("carrier")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.muted)
                Text(String(format: "%.1f Hz", session.carrierHz))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.text)
                ForEach(session.carrierTiers, id: \.self) { tier in
                    HonestyBadge(tier: tier)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                Text("beat")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.muted)
                Text(String(format: "%.2f Hz", session.beatHz))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.text)
                Text("· \(session.stateInfo.key.lowercased())")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.subtle)
                ForEach(session.beatTiers, id: \.self) { tier in
                    HonestyBadge(tier: tier)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DURATION")
                .font(.system(size: 8, weight: .light, design: .monospaced))
                .tracking(2.2)
                .foregroundColor(theme.subtle)
            HStack(spacing: 8) {
                ForEach([3, 5, 10, 15], id: \.self) { m in
                    Button(action: { duration = m }) {
                        Text("\(m) min")
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(duration == m ? accent : theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(duration == m
                                          ? Color(hue: hue / 360, saturation: 0.38, brightness: 0.14).opacity(0.85)
                                          : theme.surface)
                                    .overlay(
                                        Capsule().stroke(
                                            duration == m ? accent.opacity(0.50) : theme.border,
                                            lineWidth: 1
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var screenedBadge: some View {
        Text("SCREENED PRACTICE")
            .font(.system(size: 7.5, weight: .regular, design: .monospaced))
            .tracking(1.6)
            .foregroundColor(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.823, green: 0.510, blue: 0.196).opacity(0.35), lineWidth: 0.5)
                    )
            )
    }
}
