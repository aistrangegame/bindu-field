import SwiftUI

/// The three honesty tiers from the Frequency & Breath Atlases.
///
/// - `.science`: documented, measured, replicable physiology
/// - `.tradition`: long-standing contemplative association — true as
///                 tradition, not necessarily as physiology
/// - `.claim`: a modern assertion without solid empirical support
///
/// Rendered as a small pill via `HonestyBadge`. Lab + Akash both surface
/// these on frequency lines and in expanded knowledge panels.
enum HonestyTier: String, Hashable, CaseIterable, Codable {
    case science = "S"
    case tradition = "T"
    case claim = "C"

    var label: String {
        switch self {
        case .science:   return "SCIENCE"
        case .tradition: return "TRADITION"
        case .claim:     return "CLAIM"
        }
    }

    var oneLineDescription: String {
        switch self {
        case .science:   return "Documented, measured, replicable physiology."
        case .tradition: return "Long-standing contemplative association; true as tradition, not necessarily as physiology."
        case .claim:     return "A modern assertion without solid empirical support."
        }
    }

    var color: Color {
        switch self {
        case .science:   return Color(red: 0.282, green: 0.745, blue: 0.667)
        case .tradition: return Color(red: 0.816, green: 0.635, blue: 0.243)
        case .claim:     return Color(red: 0.765, green: 0.322, blue: 0.267)
        }
    }
}

/// A small pill that names an honesty tier — single letter when compact,
/// full label when expanded.
struct HonestyBadge: View {
    let tier: HonestyTier
    var full: Bool = false

    var body: some View {
        Text(full ? tier.label : tier.rawValue)
            .font(.system(size: 7, weight: .regular, design: .monospaced))
            .tracking(1.6)
            .foregroundColor(tier.color.opacity(0.88))
            .padding(.horizontal, full ? 7 : 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(tier.color.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(tier.color.opacity(0.32), lineWidth: 0.5)
                    )
            )
    }
}
