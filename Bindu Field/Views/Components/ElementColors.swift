import SwiftUI

extension Color {
    /// Visual color for a Track element. Accepts the Airtable string form
    /// (rawValues match the `Element` enum: "Earth", "Water", "Fire", "Air",
    /// "Light", "Crown", "Soul", "Dissolution", "Meditate", "Family").
    /// Unknown values fall back to neutral grey.
    static func bindu(element: String) -> Color {
        switch element {
        case "Earth":       return Color(hue: 15/360,  saturation: 0.55, brightness: 0.85)
        case "Water":       return Color(hue: 210/360, saturation: 0.50, brightness: 0.90)
        case "Fire":        return Color(hue: 25/360,  saturation: 0.65, brightness: 0.95)
        case "Air":         return Color(hue: 195/360, saturation: 0.40, brightness: 0.92)
        case "Light":       return Color(hue: 50/360,  saturation: 0.50, brightness: 0.95)
        case "Crown":       return Color(hue: 280/360, saturation: 0.45, brightness: 0.90)
        case "Soul":        return Color(hue: 265/360, saturation: 0.50, brightness: 0.85)
        case "Dissolution": return Color(hue: 190/360, saturation: 0.40, brightness: 0.85)
        case "Meditate":    return Color(hue: 0,       saturation: 0.0,  brightness: 0.75)
        case "Family":      return Color(hue: 330/360, saturation: 0.35, brightness: 0.88)
        default:            return Color(hue: 0,       saturation: 0.0,  brightness: 0.75)
        }
    }

    /// Hue value in degrees (0–360) for a Track element. Used when the
    /// caller wants to mix custom saturation/brightness — for example, the
    /// Oracle response glow or the Loop reveal — and a single `Color`
    /// would over-constrain the rendering. Mirrors `bindu(element:)`'s
    /// hue table exactly. Meditate and unknown elements return 0 (the
    /// caller is expected to set saturation to 0 for greyscale).
    static func binduHue(element: String) -> Double {
        switch element {
        case "Earth":       return 15
        case "Water":       return 210
        case "Fire":        return 25
        case "Air":         return 195
        case "Light":       return 50
        case "Crown":       return 280
        case "Soul":        return 265
        case "Dissolution": return 190
        case "Family":      return 330
        case "Meditate":    return 0
        default:            return 0
        }
    }

    /// Hex-string initialiser used throughout the Lalita design pass.
    /// Accepts "#RRGGBB" or "RRGGBB". Invalid input falls back to black.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .black
            return
        }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8)  & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
