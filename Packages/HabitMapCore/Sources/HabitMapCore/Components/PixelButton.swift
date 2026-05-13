import SwiftUI

public enum PixelButtonStyle: Sendable {
    case primary
    case secondary
    case destructive
}

public struct PixelButton: View {
    let title: String
    let style: PixelButtonStyle
    let accent: Color
    let action: () -> Void
    let isEnabled: Bool
    @GestureState private var pressed: Bool = false

    public init(_ title: String,
                style: PixelButtonStyle = .primary,
                accent: Color = DesignTokens.Accent.classicGreen,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.accent = accent
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: { if isEnabled { action() } }) {
            MonoText.action(title, color: textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(fillColor)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.4)
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, state, _ in state = isEnabled }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        switch style {
        case .primary:     return accent
        case .secondary:   return DesignTokens.Surface.card
        case .destructive: return DesignTokens.Surface.miss
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:     return Color.black
        case .secondary:   return accent
        case .destructive: return Color.white
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:     return accent.darker(by: 0.2)
        case .secondary:   return accent
        case .destructive: return DesignTokens.Surface.miss.darker(by: 0.2)
        }
    }
}
