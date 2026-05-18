import SwiftUI

/// Pill-style filter chip. Replaces the boxy FilterChip from earlier plans.
public struct Chip: View {
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    @GestureState private var pressed = false
    @EnvironmentObject private var haptics: Haptics

    public init(label: String, isSelected: Bool, accent: Color, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button {
            haptics.selection()
            action()
        } label: {
            Text(label)
                .font(.custom(FontFamily.sans, size: 13))
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? Color.black.opacity(0.9) : DesignTokens.Surface.fgDim())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.ultraThinMaterial))
                }
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? accent.darker(by: 0.2) : Color.white.opacity(0.08), lineWidth: 1)
                )
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
