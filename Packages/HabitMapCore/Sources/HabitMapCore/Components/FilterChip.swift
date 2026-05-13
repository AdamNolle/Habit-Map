import SwiftUI

public struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    @GestureState private var pressed: Bool = false

    public init(label: String, isSelected: Bool, accent: Color, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MonoText(label, size: .footnote, weight: .heavy,
                     color: isSelected ? .black : accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? accent : DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(isSelected ? accent.darker(by: 0.2) : accent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in state = true }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
