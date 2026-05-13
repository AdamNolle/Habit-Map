import SwiftUI

public struct FAB: View {
    let accent: Color
    let action: () -> Void
    @State private var rotation: Double = 0
    @GestureState private var pressed: Bool = false

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                action: @escaping () -> Void) {
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                rotation += 90
            }
            action()
        } label: {
            PixelIcon(.plus, color: .black, size: 22)
                .frame(width: 48, height: 48)
                .background(accent)
                .overlay(Rectangle().stroke(accent.darker(by: 0.2), lineWidth: 3))
                .rotationEffect(.degrees(rotation))
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.55), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in state = true }
        )
        .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
        .accessibilityLabel("Add habit")
        .accessibilityAddTraits(.isButton)
    }
}
