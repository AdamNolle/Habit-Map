import SwiftUI

public enum AppButtonStyle: Sendable {
    case filled       // primary CTA, accent fill, dark text
    case tinted       // soft accent fill, accent text
    case glass        // glass surface, accent text, hairline border
    case destructive  // danger fill
}

/// Refined button replacing the old PixelButton. Sans-serif label, semibold weight,
/// rounded corners, press-state scale + haptic.
public struct AppButton: View {
    let title: String
    let style: AppButtonStyle
    let accent: Color
    let icon: String?
    let isEnabled: Bool
    let action: () -> Void

    @GestureState private var pressed = false
    @EnvironmentObject private var haptics: Haptics

    public init(_ title: String,
                style: AppButtonStyle = .filled,
                accent: Color = DesignTokens.Accent.classicGreen,
                icon: String? = nil,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.accent = accent
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title)
                    .font(.custom(FontFamily.sans, size: 14))
                    .fontWeight(.semibold)
                    .kerning(0.1)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(fillStyle)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
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

    private var fillStyle: AnyShapeStyle {
        switch style {
        case .filled:      return AnyShapeStyle(accent)
        case .tinted:      return AnyShapeStyle(accent.opacity(0.12))
        case .glass:       return AnyShapeStyle(.ultraThinMaterial)
        case .destructive: return AnyShapeStyle(DesignTokens.Semantic.danger)
        }
    }

    private var textColor: Color {
        switch style {
        case .filled:      return Color.black.opacity(0.9)
        case .tinted:      return accent
        case .glass:       return accent
        case .destructive: return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled:      return accent.darker(by: 0.2)
        case .tinted:      return accent.opacity(0.35)
        case .glass:       return Color.white.opacity(0.08)
        case .destructive: return DesignTokens.Semantic.danger.darker(by: 0.2)
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .glass: return 1
        default: return 1
        }
    }
}
