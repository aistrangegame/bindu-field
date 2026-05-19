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
}
