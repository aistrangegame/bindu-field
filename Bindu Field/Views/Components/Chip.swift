import SwiftUI

struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let theme = ThemeData.void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundColor(isSelected ? theme.bg : theme.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.text : Color.clear)
                        .overlay(Capsule().stroke(theme.muted.opacity(0.35), lineWidth: isSelected ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
    }
}
