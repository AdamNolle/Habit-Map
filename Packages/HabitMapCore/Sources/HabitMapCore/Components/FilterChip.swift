import SwiftUI

public struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    public init(label: String, isSelected: Bool, accent: Color, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            PixelText(label, pixelSize: 2, color: isSelected ? .black : accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? accent : DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(isSelected ? accent.darker(by: 0.2) : accent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
