import SwiftUI

public struct FAB: View {
    let accent: Color
    let action: () -> Void
    @State private var rotation: Double = 0
    @GestureState private var pressed: Bool = false
    @EnvironmentObject private var haptics: Haptics

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                action: @escaping () -> Void) {
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button {
            haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                rotation += 90
            }
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black.opacity(0.85))
                .frame(width: 48, height: 48)
                .background(accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.darker(by: 0.2), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .rotationEffect(.degrees(rotation))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.55), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in state = true }
        )
        .shadow(color: accent.opacity(0.45), radius: 12, x: 0, y: 6)
        .accessibilityLabel("Add habit")
        .accessibilityAddTraits(.isButton)
    }
}
