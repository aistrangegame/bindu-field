import SwiftUI

struct Theme: Identifiable {
    let id: String
    let bg: Color
    let bg2: Color
    let text: Color
    let muted: Color
    let subtle: Color
    let accent: Color
    let gold: Color
    let border: Color
    let surface: Color
    let cornerRadius: CGFloat
    let hueShift: Double
}

enum ThemeData {
    static let void = Theme(id: "void",
        bg: Color(red: 0.008, green: 0.008, blue: 0.031),
        bg2: Color(red: 0.020, green: 0.020, blue: 0.059),
        text: Color(red: 0.961, green: 0.886, blue: 0.839),
        muted: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.55),
        subtle: Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.28),
        accent: Color(red: 0.831, green: 0.392, blue: 0.361),
        gold: Color(red: 0.769, green: 0.659, blue: 0.384),
        border: Color.white.opacity(0.08),
        surface: Color.white.opacity(0.042),
        cornerRadius: 10,
        hueShift: 0)

    static let dusk = Theme(id: "dusk",
        bg: Color(red: 0.047, green: 0.035, blue: 0.024),
        bg2: Color(red: 0.075, green: 0.051, blue: 0.031),
        text: Color(red: 0.929, green: 0.878, blue: 0.816),
        muted: Color(red: 0.929, green: 0.878, blue: 0.816).opacity(0.58),
        subtle: Color(red: 0.929, green: 0.878, blue: 0.816).opacity(0.30),
        accent: Color(red: 0.878, green: 0.478, blue: 0.373),
        gold: Color(red: 0.769, green: 0.647, blue: 0.345),
        border: Color(red: 1.0, green: 0.843, blue: 0.686).opacity(0.09),
        surface: Color(red: 1.0, green: 0.894, blue: 0.776).opacity(0.052),
        cornerRadius: 14,
        hueShift: 22)

    static let mist = Theme(id: "mist",
        bg: Color(red: 0.024, green: 0.051, blue: 0.078),
        bg2: Color(red: 0.039, green: 0.082, blue: 0.125),
        text: Color(red: 0.847, green: 0.910, blue: 0.941),
        muted: Color(red: 0.847, green: 0.910, blue: 0.941).opacity(0.58),
        subtle: Color(red: 0.847, green: 0.910, blue: 0.941).opacity(0.28),
        accent: Color(red: 0.420, green: 0.639, blue: 0.745),
        gold: Color(red: 0.478, green: 0.749, blue: 0.627),
        border: Color(red: 0.647, green: 0.824, blue: 1.0).opacity(0.09),
        surface: Color(red: 0.647, green: 0.824, blue: 1.0).opacity(0.052),
        cornerRadius: 16,
        hueShift: -18)

    static let all = [void, dusk, mist]
}
