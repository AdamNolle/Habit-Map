import SwiftUI

public struct FAB: View {
    let accent: Color
    let action: () -> Void

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                action: @escaping () -> Void) {
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            PixelIcon(.plus, color: .black, size: 28)
                .frame(width: 56, height: 56)
                .background(accent)
                .overlay(Rectangle().stroke(accent.darker(by: 0.2), lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add habit")
        .accessibilityAddTraits(.isButton)
    }
}
