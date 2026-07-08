import SwiftUI

/// Reading Space for breath sessions — mirrors the music Player's READING
/// mode ("the same room"). Four tabs: WORDS · FREQUENCY · LALITA · PHASES.
///
/// All four tabs read from Airtable (lyricalWordsReading, frequencyReading,
/// lalitasPerspective, phaseLabels). When a tab's source is empty the view
/// surfaces a graceful "still forming" stub so the tab isn't blank.
///
/// `[SCIENCE]` / `[TRADITION]` / `[CLAIM]` paragraphs in the FREQUENCY
/// prose are detected by prefix and rendered in a tier-styled card with
/// the corresponding badge — this lets the writer mark physiology-level
/// claims inline without needing a separate field.
struct BreathReadingSpaceView: View {
    let session: JoinedBreathSession
    let onBack: () -> Void

    @State private var tab: Tab = .words
    @Environment(\.binduTheme) private var theme

    enum Tab: String, CaseIterable {
        case words = "WORDS"
        case frequency = "FREQUENCY"
        case lalita = "LALITA"
        case phases = "PHASES"
    }

    private var hue: Double { session.hue }
    private var accent: Color {
        Color(hue: hue / 360, saturation: 0.52, brightness: 0.68)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(hue: hue / 360, saturation: 0.32, brightness: 0.08).opacity(0.18),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.20),
                startRadius: 30,
                endRadius: 380
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                tabBar
                ScrollView(showsIndicators: false) {
                    tabContent
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Text("← \(session.name.uppercased())")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(theme.subtle)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)

            if let rec = session.recognitionStatement, !rec.isEmpty {
                Text("\"\(rec)\"")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(Color(hue: hue / 360, saturation: 0.45, brightness: 0.72).opacity(0.80))
                    .lineSpacing(4)
                    .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    // MARK: - Tab bar

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { tab = t } }) {
                    VStack(spacing: 8) {
                        Text(t.rawValue)
                            .font(.system(size: 9, weight: .light, design: .monospaced))
                            .tracking(1.8)
                            .foregroundColor(t == tab ? theme.text : theme.subtle)
                        Rectangle()
                            .fill(t == tab ? accent : Color.clear)
                            .frame(height: 1)
                            .padding(.horizontal, 22)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .words:     wordsTab
        case .frequency: frequencyTab
        case .lalita:    lalitaTab
        case .phases:    phasesTab
        }
    }

    @ViewBuilder
    private var wordsTab: some View {
        let prose = session.lyricalWordsReading
        if prose.isEmpty {
            placeholderText("This session's words reading is still being written.")
        } else {
            paragraphedProse(prose, accentLast: true)
        }
    }

    @ViewBuilder
    private var frequencyTab: some View {
        let prose = session.frequencyReading
        VStack(alignment: .leading, spacing: 18) {
            if prose.isEmpty {
                placeholderText("The frequency reading for this session is still forming.")
            } else {
                ForEach(prose.paragraphs.indices, id: \.self) { i in
                    let para = prose.paragraphs[i]
                    if let tier = detectTierPrefix(para) {
                        tierCard(tier: tier, body: stripTierPrefix(para))
                    } else {
                        Text(para)
                            .font(.system(size: 14.5, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Tier legend
            Rectangle().fill(theme.border).frame(height: 1).padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(HonestyTier.allCases, id: \.self) { tier in
                    HStack(alignment: .top, spacing: 8) {
                        HonestyBadge(tier: tier)
                        Text(tier.oneLineDescription)
                            .font(.system(size: 10, design: .serif))
                            .italic()
                            .foregroundColor(theme.subtle.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var lalitaTab: some View {
        if let prose = session.lalitasPerspective, !prose.isEmpty {
            paragraphedProse(prose, accentLast: true)
        } else {
            placeholderText("Lalita's perspective for this session has not yet arrived.")
        }
    }

    @ViewBuilder
    private var phasesTab: some View {
        if let labels = session.phaseLabels, !labels.isEmpty {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(labels.paragraphs.indices, id: \.self) { i in
                    let para = labels.paragraphs[i]
                    let split = splitPhase(para)
                    VStack(alignment: .leading, spacing: 6) {
                        if let head = split.head {
                            Text(head.uppercased())
                                .font(.system(size: 8, weight: .light, design: .monospaced))
                                .tracking(2.2)
                                .foregroundColor(Color(hue: hue / 360, saturation: 0.42, brightness: 0.60).opacity(0.75))
                        }
                        Text(split.body)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 16)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color(hue: hue / 360, saturation: 0.35, brightness: 0.35).opacity(0.25))
                            .frame(width: 1)
                    }
                }
            }
        } else {
            placeholderText("The phase map for this session is still being written.")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func placeholderText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 14, design: .serif))
            .italic()
            .foregroundColor(theme.subtle.opacity(0.55))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func paragraphedProse(_ prose: String, accentLast: Bool) -> some View {
        let paras = prose.paragraphs
        VStack(alignment: .leading, spacing: 18) {
            ForEach(paras.indices, id: \.self) { i in
                Text(paras[i])
                    .font(.system(size: 14.5, design: .serif))
                    .italic()
                    .foregroundColor(
                        accentLast && i == paras.count - 1
                            ? Color(hue: hue / 360, saturation: 0.40, brightness: 0.72).opacity(0.85)
                            : theme.muted
                    )
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func tierCard(tier: HonestyTier, body: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(theme.border)
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HonestyBadge(tier: tier, full: true)
                    Spacer(minLength: 0)
                }
                Text(body)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(theme.subtle.opacity(0.70))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface)
        )
    }

    private func detectTierPrefix(_ s: String) -> HonestyTier? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[SCIENCE]") { return .science }
        if trimmed.hasPrefix("[TRADITION]") { return .tradition }
        if trimmed.hasPrefix("[CLAIM]") { return .claim }
        return nil
    }

    private func stripTierPrefix(_ s: String) -> String {
        guard let close = s.firstIndex(of: "]") else { return s }
        let after = s.index(after: close)
        return String(s[after...]).trimmingCharacters(in: .whitespaces)
    }

    /// Split a paragraph that may be "Phase Name · 0–3 min — description"
    /// into a head label ("Phase Name · 0–3 min") and body. Falls back to
    /// the whole paragraph as body.
    private func splitPhase(_ s: String) -> (head: String?, body: String) {
        if let range = s.range(of: " — ") {
            return (String(s[..<range.lowerBound]), String(s[range.upperBound...]))
        }
        if let range = s.range(of: ": ") {
            return (String(s[..<range.lowerBound]), String(s[range.upperBound...]))
        }
        return (nil, s)
    }
}

private extension String {
    /// Split on blank lines into paragraphs; trim and drop empties. Used by
    /// the breath Reading Space (and matches the music Player's READING
    /// behavior).
    var paragraphs: [String] {
        components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
