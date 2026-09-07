import SwiftUI

// Parser + renderer for a music track's authored Phase Labels — the
// composed arc of the song, surfaced in the Player READING sheet's PHASES
// tab.
//
// Song Phase Labels are stored in Airtable (`Phase Labels` column) in the
// web-player object-array format — NOT the breath Reading Space's blank-line
// `HEAD — body` paragraph format. A real example (Iron / Sound of Silence):
//
//     [
//       {t: 0, name: 'silence', sub: 'the carrier arrives before the prophet speaks'},
//       {t: 13, name: 'gathering', sub: 'a vision softly creeping...'},
//     ]
//
// It is not valid JSON (unquoted keys, single quotes, trailing commas,
// apostrophes and commas inside the `sub` values), so `SongPhaseParser`
// scans it tolerantly and TOTALLY: any malformed input yields as many
// phases as it can read, or an empty array — it never throws. The renderer
// mirrors `BreathReadingSpaceView`'s PHASES styling so a song's arc reads
// the same as a breath session's.

struct SongPhase: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let sub: String
}

enum SongPhaseParser {
    /// Parse the web-player object-array Phase Labels string into an ordered
    /// list of `{name, sub}` phases. Returns `[]` for nil / empty / anything
    /// it can't read — never throws.
    static func parse(_ raw: String?) -> [SongPhase] {
        guard let raw, !raw.isEmpty else { return [] }
        // Each phase is a `{ … }` object; splitting on the closing brace
        // leaves each chunk holding at most one object's fields.
        var phases: [SongPhase] = []
        for chunk in raw.components(separatedBy: "}") {
            guard chunk.contains("name") else { continue }
            let name = boundedValue(of: "name", in: chunk, before: "sub") ?? ""
            let sub = trailingValue(of: "sub", in: chunk) ?? ""
            if !name.isEmpty || !sub.isEmpty {
                phases.append(SongPhase(name: name, sub: sub))
            }
        }
        return phases
    }

    private static func isQuote(_ c: Character) -> Bool {
        c == "'" || c == "\""
            || c == "\u{2018}" || c == "\u{2019}"   // ‘ ’
            || c == "\u{201C}" || c == "\u{201D}"   // “ ”
    }

    /// Value of `key`, bounded on the right by the next key `before` so an
    /// earlier field's quotes can't run past its own value.
    private static func boundedValue(of key: String, in chunk: String, before: String) -> String? {
        guard let kr = chunk.range(of: key + ":") else { return nil }
        var seg = String(chunk[kr.upperBound...])
        if let br = seg.range(of: before + ":") {
            seg = String(seg[..<br.lowerBound])
        }
        return unquote(seg)
    }

    /// Value of a trailing `key` (the last field before `}`): everything
    /// from after `key:` to the last quote in the chunk, so apostrophes and
    /// commas inside the value are preserved.
    private static func trailingValue(of key: String, in chunk: String) -> String? {
        guard let kr = chunk.range(of: key + ":") else { return nil }
        return unquote(String(chunk[kr.upperBound...]))
    }

    /// Trim surrounding whitespace and trailing commas, then strip one
    /// matching quote at each end. Tolerant of smart quotes and of a value
    /// that carries no quotes at all.
    private static func unquote(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, last == "," {
            t.removeLast()
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let first = t.first, isQuote(first) else {
            return t.isEmpty ? nil : t
        }
        t.removeFirst()
        if let last = t.last, isQuote(last) { t.removeLast() }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Renders a track's parsed arc as the Player READING sheet's PHASES tab.
/// Same visual grammar as the breath Reading Space: a left hairline rule, a
/// small uppercased name, and an italic-serif line of description.
struct SongPhaseReadingView: View {
    let phaseLabels: String?
    let accent: Color
    let theme: Theme

    var body: some View {
        let phases = SongPhaseParser.parse(phaseLabels)
        if phases.isEmpty {
            Text("the phase map for this song is still forming.")
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundColor(theme.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        if !phase.name.isEmpty {
                            Text(phase.name.uppercased())
                                .font(.system(size: 8, weight: .light, design: .monospaced))
                                .tracking(2.2)
                                .foregroundColor(accent.opacity(0.75))
                        }
                        Text(phase.sub)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundColor(theme.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 16)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(accent.opacity(0.25))
                            .frame(width: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
